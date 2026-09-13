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
///   - any non-Dart write → run (slang translation sources, assets);
///   - any Dart write whose RAW content mentions a builder-facing
///     annotation (`@Zorphy`, `@ZorphyMixin`, `@JsonSerializable`,
///     `@HiveType`, `@HiveField`, `@Route`, `@ZfaRoute`) → run.
///
/// The annotation match is RAW (comments count) — the same content-
/// filter pattern the DDA route stage itself uses
/// (`_contentFilter = RegExp(r'@(Route|ZfaRoute)\b')`). A comment
/// mentioning an annotation only ever makes the build RUN; the gate
/// never skips on a guess.
///
/// This is a scheduling decision only: the `zfa build` command, the
/// analyze gate, and the run-loop state machine are untouched. When the
/// build runs, every downstream guard (#737 tolerance, #942 analyzer
/// errors, #1407 warnings-only refusal) sees a real executed step.
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
  /// stay machine-findable.
  static const String skippedBuildNote =
      'terminal build step skipped: no builder-consumable input changed '
      'since the plan started (issue #1587) — build_runner and the '
      'analyze gate would see an unchanged builder surface.';

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
  /// and decide against the [before] fingerprint. Any unreadable file
  /// fails the decision toward RUN (the safe direction) — a filesystem
  /// hiccup must never fabricate a skip.
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
    } on FileSystemException {
      return false;
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
    return hash.toRadixString(16);
  }
}
