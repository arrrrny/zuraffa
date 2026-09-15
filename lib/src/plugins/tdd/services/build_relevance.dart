/// `BuildRelevance` — the make plan's terminal `build` step gate
/// (issue #1587).
///
/// Every expressible generation plan terminates in a `zfa build` step
/// (build_runner + the whole-project analyze gate). On a feature whose
/// generation writes only plain Dart — subjects and tests no builder
/// consumes — that step measured 18–45s per behavior while emitting
/// ZERO outputs: pure overhead (issue #1587). This service decides,
/// from a content fingerprint of the project, whether the build step
/// has anything to do.
///
/// The decision is deliberately CONSERVATIVE — the build runs unless
/// every changed file provably cannot feed a builder:
///   - any deletion → run (a deleted annotated source leaves stale
///     outputs);
///   - any build config change (`pubspec.yaml`, `pubspec.lock`,
///     `build.yaml`, `analysis_options.yaml`, `dart_test.yaml`,
///     `.zfa.json`, `.dart_tool/package_config.json`) → run;
///   - any non-Dart write inside the fingerprinted roots (`lib/`,
///     `test/`, `bin/`, `tool/` — slang translation sources and assets
///     written there) → run;
///   - any Dart write whose RAW content mentions a builder-facing
///     annotation (`@Zorphy`, `@ZorphyMixin`, `@JsonSerializable`,
///     `@HiveType`, `@HiveField`, `@Route`, `@ZfaRoute`) → run.
///
/// Coverage boundary (issue #1587 review): [fingerprint] covers those
/// four Dart roots plus [buildConfigFiles] and NOTHING else — a write
/// outside them (a top-level `assets/`, a root `slang.yaml`, `web/`, a
/// coverage or report file) never enters the changed set, so it does
/// not by itself force a build. Widening the walk to the whole project
/// tree was considered and rejected deliberately: the generation
/// steps' own transient artifacts (tool logs, coverage output) would
/// then register as changes and permanently disable the skip — a
/// bigger loss than the uncovered writes it would catch. The gate is
/// exactly as conservative as the roots listed here.
///
/// The annotation match is RAW (comments count) — the same content-
/// filter pattern the DDA route stage itself uses
/// (`_contentFilter = RegExp(r'@(Route|ZfaRoute)\b')`). A comment
/// mentioning an annotation only ever makes the build RUN; the gate
/// never skips on a guess.
///
/// This is a scheduling decision only: the `zfa build` command and the
/// run-loop state machine are untouched. A SKIPPED build also skips
/// `zfa build`'s whole-project `dart analyze lib/` stage — its verdict
/// is the make's analyzer grading, and no other TDD step runs it on
/// this path — so [skippedBuildNote] states that trade-off explicitly
/// instead of leaving a reader to assume generated `lib/` code was
/// analyzed. When the build runs, every downstream guard (#737
/// tolerance, #942 analyzer errors, #1407 warnings-only refusal) sees a
/// real executed step.
///
/// Issue #1624 — the REFACTOR's build pass. After the #1587 fix made the
/// make's per-behavior build skippable, `zfa tdd refactor`'s own `build`
/// pass became the dominant cost of a green behavior (the pass registry
/// spawns a whole-project `zfa build` per refactor: build_runner + the
/// whole-project `dart analyze lib/`). On a feature whose generation
/// writes only plain Dart that pass re-derives nothing. Unlike the make
/// gate, the refactor gate has no "before" fingerprint to diff against —
/// the refactor did not write the tree — so it decides from the tree's
/// relationship to build_runner's own state: the
/// `.dart_tool/build/asset_graph.json` marker. Only files not older than
/// that marker can hold input build_runner has not already consumed, and
/// even then only a builder-facing annotation (or a config / non-Dart
/// file) makes the pass necessary. [refactorBuildSkipNote] is that gate;
/// its decision fails toward RUN on every unknown.
///
/// Issue #1634 — the FIRST build. The marker-mtime relationship needs a
/// marker, and a fresh app has none until its first build completes, so
/// the #1624 gate's missing-marker fail-open paid the one-time
/// build_runner entrypoint AOT compile (~4 min measured: `gen_snapshot`
/// compiling an ~18.5 MB `build.dart.aot`) inside the FIRST refactor —
/// exactly on the app state where skipping matters most, for features
/// whose builders emit nothing. When there is no build_runner state at
/// all (no `.dart_tool/build/` directory), the graph is only needed to
/// reason about INCREMENTAL freshness — not about "nothing here can ever
/// feed a builder" — so [refactorBuildSkipNote] decides STATICALLY from
/// a source scan: any builder-facing annotation, any non-Dart source
/// inside the walked roots, or any `build.yaml` at the project root runs
/// the first build (creating the graph the incremental gate then uses);
/// a tree with none of those skips it via [staticFirstBuildSkippedNote]
/// and never pays the AOT compile. The other [buildConfigFiles] are
/// deliberately not static triggers — they exist on every app, so their
/// presence cannot discriminate "nothing builder-facing". After a static
/// skip there is still no state, so every later refactor re-enters the
/// static scan until a real build creates the graph: self-consistent,
/// and the build happens exactly when a builder-facing file appears. The
/// cost of that re-scan is a full content read of every Dart file under
/// the roots on each refactor (the incremental path reads mtimes only) —
/// negligible for a fresh app, a per-refactor full-tree read for a large
/// no-graph tree, and still orders of magnitude cheaper than the
/// entrypoint AOT compile the skip avoids.
///
/// The price of having no "before" state is the deletion blind spot, and
/// the gate does NOT pretend otherwise: [canSkipTerminalBuild] runs on any
/// deletion (its rule 1), but a path removed since the last build is
/// simply absent from the walk here, so a deletion alone never forces the
/// pass. Reading an mtime-ordered graph — whose serialized shape differs
/// between build_runner versions (a dict at asset-graph version 44, a list
/// at 47, 0.9–2.3 MB on a real project) — to recover "outputs that should
/// exist" is not worth the fragility on this path; [refactorBuildSkippedNote]
/// states the blind spot instead of over-claiming, so the recorded
/// evidence stays true. The static first-build decision has the mirrored
/// honesty ([staticFirstBuildSkippedNote]): it proves what the CONTENT
/// scan covered and nothing else — a tree whose generated outputs exist
/// without `.dart_tool/` (copied without build state) and whose sources
/// reference them un-annotated is outside its model. What bounds the blast
/// radius in both cases is the absolute-green preflight: a missing `part`
/// target breaks compilation, so the refactor refuses before the passes
/// run.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class BuildRelevance {
  const BuildRelevance._();

  /// Build config files whose change always requires a build (builder
  /// registration, dependency graph, analyzer options, feature flags).
  static const Set<String> buildConfigFiles = <String>{
    'pubspec.yaml',
    'pubspec.lock',
    'build.yaml',
    'analysis_options.yaml',
    'dart_test.yaml',
    '.zfa.json',
    '.dart_tool/package_config.json',
  };

  /// The four source roots every tree walk covers: [fingerprint]'s
  /// content hash, the refactor gate's incremental mtime walk, and the
  /// #1634 static first-build scan. One constant, not three inline
  /// literals (issue #1634 review): the static scan's SKIP is only sound
  /// if it covers exactly what the incremental walk considers, so the
  /// consumers must not be able to drift apart.
  static const List<String> _walkedRoots = <String>[
    'lib',
    'test',
    'bin',
    'tool',
  ];

  /// The shared walk filter for [_walkedRoots]: files only, and never
  /// `*.g.dart.part` (build_runner's transient pre-output, not a real
  /// source). Returns the entity as a [File] so the callers' reads keep
  /// the type promotion — the same idiom all three walks apply.
  static File? _walkedSource(FileSystemEntity entity) =>
      entity is File && !entity.path.endsWith('.g.dart.part') ? entity : null;

  /// The builder-facing annotations `zfa build`'s stages consume: the
  /// zorphy entity builder, json_serializable, the hive_ce generators,
  /// and the DDA route stage. Raw-content match (comments count — the
  /// fail-safe direction).
  static final RegExp builderFacingAnnotation = RegExp(
    r'@(Zorphy(?:Mixin)?|JsonSerializable|HiveType|HiveField|Route|ZfaRoute)\b',
  );

  /// The skip note recorded on a synthetic skipped build step and
  /// printed by the make. Names the issue so the audit and the run log
  /// stay machine-findable, and states the analyze-gate trade-off
  /// explicitly (issue #1587 review) so a reader never assumes the
  /// skipped step's writes were analyzer-graded.
  static const String skippedBuildNote =
      'terminal build step skipped: no builder-consumable input changed '
      'since the plan started (issue #1587) — build_runner would '
      're-derive identical outputs, and the whole-project `dart analyze '
      'lib/` stage `zfa build` also runs was skipped with it, so these '
      'plain-Dart writes were not analyzer-graded.';

  /// The skip note the refactor's `build` pass records when
  /// [refactorBuildSkipNote] decides the pass has nothing to do (issue
  /// #1624). Mirrors [skippedBuildNote]'s honesty: names the issue and
  /// states the skipped whole-project `dart analyze lib/` stage
  /// explicitly so a reader never assumes the pass's writes were
  /// analyzer-graded.
  ///
  /// It claims what the gate can actually PROVE — no file newer than the
  /// asset-graph marker can feed a builder — and not that build_runner
  /// "would re-derive identical outputs": a path DELETED since that build
  /// never enters the newer set, so this gate cannot see a deletion (the
  /// make gate's fingerprint diff can; [canSkipTerminalBuild] rule 1).
  static const String refactorBuildSkippedNote =
      'refactor build pass skipped: every file newer than the build_runner '
      'asset graph is un-annotated plain Dart (issue #1624) — nothing '
      'newer than that asset graph can feed a builder. A path DELETED since '
      'that build is invisible to this gate (it has no pre-build '
      'fingerprint to diff against), so the skip is not evidence that the '
      'tree\'s generated outputs are all still on disk. The whole-project '
      '`dart analyze lib/` stage `zfa build` also runs was skipped with it, '
      'so these plain-Dart writes were not analyzer-graded.';

  /// The skip note the refactor's `build` pass records when
  /// [refactorBuildSkipNote] decides STATICALLY — build_runner has no
  /// state in the project at all (no `.dart_tool/build/` directory) and
  /// the source scan found nothing a first build could emit (issue
  /// #1634). This is the note that spares a fresh app's FIRST refactor
  /// the one-time build_runner entrypoint AOT compile (~4 min measured)
  /// the #1624 gate could never skip: the gate used to fail open on the
  /// missing marker, paying the full first build for features that
  /// generate nothing.
  ///
  /// It claims what the static scan PROVES — no builder-facing
  /// annotation, no non-Dart source inside the walked roots, and no
  /// `build.yaml` at the project root (the only location build_runner
  /// reads config from) — and states the boundaries
  /// honestly: the skipped `zfa build`'s whole-project
  /// `dart analyze lib/` stage was skipped with it (these plain-Dart
  /// writes were not analyzer-graded), and a tree whose generated
  /// outputs are present WITHOUT `.dart_tool/` (copied without build
  /// state) and whose sources reference them un-annotated is outside
  /// this scan's model — the absolute-green preflight bounds that case
  /// (a missing `part` target breaks compilation before the passes
  /// run), the same blast-radius bound the incremental note leans on.
  static const String staticFirstBuildSkippedNote =
      'refactor build pass skipped: build_runner has never run here (no '
      '.dart_tool/build/ state) and the static source scan found nothing a '
      'first build could emit — no builder-facing annotation, no non-Dart '
      'source inside lib/test/bin/tool, no build.yaml (issue #1634) — so '
      'the one-time build_runner entrypoint AOT compile is not paid. If a '
      'builder-facing file appears, the next refactor runs the first build '
      'and creates the asset graph. The whole-project `dart analyze lib/` '
      'stage `zfa build` also runs was skipped with it, so these '
      'plain-Dart writes were not analyzer-graded.';

  /// Fingerprint the build-relevant tree: a content digest per file,
  /// keyed by project-relative POSIX paths. Covers the Dart source dirs
  /// the builders and the analyze gate consume (`lib/`, `test/`,
  /// `bin/`, `tool/`) plus [buildConfigFiles]. Deleted files are simply
  /// absent from a later fingerprint — the deletion detection.
  static Future<Map<String, String>> fingerprint({
    required String projectRoot,
  }) async {
    final hashes = <String, String>{};
    for (final dir in _walkedRoots) {
      final directory = Directory(p.join(projectRoot, dir));
      if (!directory.existsSync()) continue;
      await _hashTree(directory, projectRoot, hashes);
    }
    for (final config in buildConfigFiles) {
      final file = File(p.join(projectRoot, config));
      if (!file.existsSync()) continue;
      hashes[config] = _digestOf(await file.readAsBytes());
    }
    return hashes;
  }

  /// The gate over two fingerprints. [readContent] supplies the CURRENT
  /// content of a changed file (only changed paths are queried); the
  /// caller decides how to read it (and how to fail on an unreadable
  /// file — an exception here aborts the skip, never the make).
  static bool canSkipTerminalBuild({
    required Map<String, String> before,
    required Map<String, String> after,
    required String Function(String path) readContent,
  }) {
    // 1. Any deletion → run (stale builder outputs are not worth a
    //    guess).
    for (final path in before.keys) {
      if (!after.containsKey(path)) return false;
    }
    for (final entry in after.entries) {
      final path = entry.key;
      final beforeHash = before[path];
      // Unchanged or brand-new files only from here on; a new file has
      // no builder output to invalidate yet.
      if (beforeHash != null && beforeHash == entry.value) continue;
      // 2. Config change → run.
      if (buildConfigFiles.contains(path)) return false;
      // 3. Non-Dart write → run (slang sources, assets).
      if (!path.endsWith('.dart')) return false;
      // 4. Builder-facing content → run (raw match).
      if (builderFacingAnnotation.hasMatch(readContent(path))) return false;
    }
    return true;
  }

  /// Convenience for the pipeline runner: re-fingerprint [projectRoot]
  /// and decide against the [before] fingerprint. Any failure —
  /// filesystem, decode, or a file that vanished mid-walk — fails the
  /// decision toward RUN (the safe direction): a hiccup must never
  /// fabricate a skip, and must never escape the make.
  static Future<bool> shouldSkipTerminalBuild({
    required String projectRoot,
    required Map<String, String> before,
  }) async {
    try {
      final after = await fingerprint(projectRoot: projectRoot);
      return canSkipTerminalBuild(
        before: before,
        after: after,
        readContent: (path) =>
            File(p.join(projectRoot, path)).readAsStringSync(),
      );
    } catch (_) {
      // Issue #1587 review (finding 1): catch EVERYTHING, not just
      // FileSystemException. `readAsStringSync` on a `.dart` file that
      // is not valid UTF-8 raises FormatException, and a file removed
      // between the walk and the read raises out of `fingerprint` too.
      // An escaping error would abort the make after generation already
      // rewrote the subject — the run loop's state machine would never
      // see a graded outcome.
      return false;
    }
  }

  /// Issue #1624: the refactor `build` pass's scheduling gate; issue
  /// #1634: the FIRST-build decision is no longer a blanket fail-open.
  ///
  /// Non-null = a skip note (the pass is recorded as a synthetic skipped
  /// action and never spawned); null = run the build. The refactor did
  /// not write the tree, so there is no "before" fingerprint to diff
  /// against — the gate instead compares the tree against build_runner's
  /// own state marker, `.dart_tool/build/asset_graph.json`:
  ///
  ///   1. Marker missing AND `.dart_tool/build/` absent (issue #1634) →
  ///      decide STATICALLY from a source scan, without consulting any
  ///      graph (see [staticFirstBuildSkippedNote]):
  ///      1a. Any non-Dart file under `lib/`, `test/`, `bin/`, `tool/`
  ///          (slang translation sources, assets) → run.
  ///      1b. Any `.dart` file whose RAW content matches
  ///          [builderFacingAnnotation] (comments count) → run.
  ///      1c. Any `build.yaml` at the project root (builder
  ///          registration — `zfa build`'s guard auto-scaffolds one on
  ///          the first build, so its presence without a graph means a
  ///          builder was configured or `.dart_tool` was cleaned) → run.
  ///      1d. Otherwise → skip statically. The other [buildConfigFiles]
  ///          are deliberately NOT triggers: they exist on EVERY app
  ///          (fresh or not), so their mere presence cannot
  ///          discriminate "nothing builder-facing" and would disable
  ///          the static skip forever — re-creating the #1634 cost.
  ///   2. Marker missing but `.dart_tool/build/` present (a mid-build
  ///      or partially cleaned state) → run (unknown — fail toward RUN).
  ///   3. Collect every file under `lib/`, `test/`, `bin/`, `tool/`
  ///      (skipping `*.g.dart.part`) plus [buildConfigFiles] whose mtime
  ///      is NOT before the marker's — the conservative `>=` direction.
  ///   4. No such file → skip (nothing has been written since the last
  ///      build).
  ///   5. Any such file that is a config file, is not `.dart`, or whose
  ///      RAW content matches [builderFacingAnnotation] → run.
  ///   6. Otherwise (every newer file is un-annotated plain Dart) → skip.
  ///
  /// Every filesystem/read error → null (run): a hiccup must never
  /// fabricate a skip, exactly like [shouldSkipTerminalBuild].
  static Future<String?> refactorBuildSkipNote({
    required String projectRoot,
  }) async {
    try {
      final marker = File(
        p.join(projectRoot, '.dart_tool', 'build', 'asset_graph.json'),
      );
      if (!marker.existsSync()) {
        // Issue #1634: no build_runner state at all — the graph is only
        // needed to reason about INCREMENTAL freshness, not about
        // "nothing here can ever feed a builder". Decide statically.
        final buildDir = Directory(p.join(projectRoot, '.dart_tool', 'build'));
        if (!buildDir.existsSync()) {
          // `await` is LOAD-BEARING: a bare `return future` would hand the
          // static scan's error straight to the caller — bypassing this
          // catch — and a decode hiccup would abort the refactor instead
          // of failing the decision toward RUN (issue #1634 S6).
          return await _staticFirstBuildSkipNote(projectRoot: projectRoot);
        }
        return null;
      }
      final markerModified = marker.statSync().modified;

      final newer = <String>[];
      for (final dir in _walkedRoots) {
        final directory = Directory(p.join(projectRoot, dir));
        if (!directory.existsSync()) continue;
        await for (final entity in directory.list(recursive: true)) {
          final file = _walkedSource(entity);
          if (file == null) continue;
          if (file.statSync().modified.isBefore(markerModified)) continue;
          newer.add(
            p.relative(file.path, from: projectRoot).replaceAll(r'\', '/'),
          );
        }
      }
      for (final config in buildConfigFiles) {
        final file = File(p.join(projectRoot, config));
        if (!file.existsSync()) continue;
        if (file.statSync().modified.isBefore(markerModified)) continue;
        newer.add(config);
      }
      if (newer.isEmpty) return refactorBuildSkippedNote;

      for (final path in newer) {
        if (buildConfigFiles.contains(path)) return null;
        if (!path.endsWith('.dart')) return null;
        if (builderFacingAnnotation.hasMatch(
          await File(p.join(projectRoot, path)).readAsString(),
        )) {
          return null;
        }
      }
      return refactorBuildSkippedNote;
    } catch (_) {
      // Fail toward RUN: a decode error, an unreadable stat, a file that
      // vanished mid-walk — none of them may fabricate a skip.
      return null;
    }
  }

  /// Issue #1634: the static first-build decision — a source scan of the
  /// build-relevant trees with NO graph consulted (there is none). The
  /// walk mirrors the incremental one (same roots, same `*.g.dart.part`
  /// skip) but reads CONTENT instead of mtimes: any non-Dart file or any
  /// [builderFacingAnnotation] match runs the build; any `build.yaml` at
  /// the project root runs it too. All errors propagate to the caller's
  /// catch — the decision fails toward RUN, never fabricates a skip.
  static Future<String?> _staticFirstBuildSkipNote({
    required String projectRoot,
  }) async {
    if (File(p.join(projectRoot, 'build.yaml')).existsSync()) return null;
    for (final dir in _walkedRoots) {
      final directory = Directory(p.join(projectRoot, dir));
      if (!directory.existsSync()) continue;
      await for (final entity in directory.list(recursive: true)) {
        final file = _walkedSource(entity);
        if (file == null) continue;
        if (!file.path.endsWith('.dart')) return null;
        if (builderFacingAnnotation.hasMatch(await file.readAsString())) {
          return null;
        }
      }
    }
    return staticFirstBuildSkippedNote;
  }

  static Future<void> _hashTree(
    Directory directory,
    String projectRoot,
    Map<String, String> hashes,
  ) async {
    await for (final entity in directory.list(recursive: true)) {
      final file = _walkedSource(entity);
      if (file == null) continue;
      final relative = p
          .relative(file.path, from: projectRoot)
          .replaceAll(r'\', '/');
      hashes[relative] = _digestOf(await file.readAsBytes());
    }
  }

  static String _digestOf(List<int> bytes) {
    // A cheap, stable content digest; `crypto`'s sha256 via its
    // streaming API would pull the whole crypto import graph into a
    // pure service — a 64-bit FNV-1a over the bytes is enough to
    // detect the make's own writes (the drift threat model here is the
    // make's generation steps, not adversarial collisions).
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    // The seed is a NEGATIVE signed 64-bit literal in Dart, so a bare
    // `toRadixString(16)` renders most digests as negative hex
    // (issue #1587 review, finding 5). Render the unsigned 64-bit value
    // zero-padded to the full width a reader expects from the digest.
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }
}
