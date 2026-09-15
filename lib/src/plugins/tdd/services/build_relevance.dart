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
  /// #1624). Mirrors [skippedBuildNote]'s honesty: names the issue,
  /// states that build_runner would re-derive identical outputs, and
  /// states the skipped whole-project `dart analyze lib/` stage
  /// explicitly so a reader never assumes the pass's writes were
  /// analyzer-graded.
  static const String refactorBuildSkippedNote =
      'refactor build pass skipped: every file newer than the build_runner '
      'asset graph is un-annotated plain Dart (issue #1624) — build_runner '
      'would re-derive identical outputs, and the whole-project `dart '
      'analyze lib/` stage `zfa build` also runs was skipped with it, so '
      'these plain-Dart writes were not analyzer-graded.';

  /// Fingerprint the build-relevant tree: a content digest per file,
  /// keyed by project-relative POSIX paths. Covers the Dart source dirs
  /// the builders and the analyze gate consume (`lib/`, `test/`,
  /// `bin/`, `tool/`) plus [buildConfigFiles]. Deleted files are simply
  /// absent from a later fingerprint — the deletion detection.
  static Future<Map<String, String>> fingerprint({
    required String projectRoot,
  }) async {
    final hashes = <String, String>{};
    for (final dir in const ['lib', 'test', 'bin', 'tool']) {
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

  /// Issue #1624: the refactor `build` pass's scheduling gate.
  ///
  /// Non-null = a skip note (the pass is recorded as a synthetic skipped
  /// action and never spawned); null = run the build. The refactor did
  /// not write the tree, so there is no "before" fingerprint to diff
  /// against — the gate instead compares the tree against build_runner's
  /// own state marker, `.dart_tool/build/asset_graph.json`:
  ///
  ///   1. Marker missing → run (the project has never been built here;
  ///      nothing proves an existing asset graph).
  ///   2. Collect every file under `lib/`, `test/`, `bin/`, `tool/`
  ///      (skipping `*.g.dart.part`) plus [buildConfigFiles] whose mtime
  ///      is NOT before the marker's — the conservative `>=` direction.
  ///   3. No such file → skip (nothing has been written since the last
  ///      build).
  ///   4. Any such file that is a config file, is not `.dart`, or whose
  ///      RAW content matches [builderFacingAnnotation] → run.
  ///   5. Otherwise (every newer file is un-annotated plain Dart) → skip.
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
      if (!marker.existsSync()) return null;
      final markerModified = marker.statSync().modified;

      final newer = <String>[];
      for (final dir in const ['lib', 'test', 'bin', 'tool']) {
        final directory = Directory(p.join(projectRoot, dir));
        if (!directory.existsSync()) continue;
        await for (final entity in directory.list(recursive: true)) {
          if (entity is! File) continue;
          if (entity.path.endsWith('.g.dart.part')) continue;
          if (entity.statSync().modified.isBefore(markerModified)) continue;
          newer.add(
            p.relative(entity.path, from: projectRoot).replaceAll(r'\', '/'),
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

  static Future<void> _hashTree(
    Directory directory,
    String projectRoot,
    Map<String, String> hashes,
  ) async {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.g.dart.part')) continue;
      final relative = p
          .relative(entity.path, from: projectRoot)
          .replaceAll(r'\', '/');
      hashes[relative] = _digestOf(await entity.readAsBytes());
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
