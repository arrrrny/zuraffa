/// The trimmed re-certification scope and decision (spec 1529, US3).
///
/// A make step's guard re-runs the suite to prove the generation broke
/// nothing. The full suite is the blunt instrument: its cost grows with
/// every behavior the feature adds (the issue's quadratic-growth
/// observation). The trim replaces it with the narrowest set that proves
/// the same thing about the writes make actually made:
///
/// - [RecertScope.compute] — the import-closure scope: the behavior's
///   own test plus every test whose transitive import closure (imports,
///   exports, parts; relative and self-package URIs) reaches the
///   declared write set (FR-8). A pure filesystem computation.
/// - [SourceWriteProbe] — the untouched-rest proof's second half (FR-9b):
///   a stat snapshot of every project `.dart` file under `lib/` and
///   `test/` taken BEFORE the pipeline runs, diffed after; the proof
///   holds when every changed file is inside the declared set.
/// - [planGuardRecert] — the fail-closed decision (FR-9/FR-10/FR-11):
///   the trimmed run is selected ONLY when the dependency fingerprint is
///   provable AND the write probe confined make's writes to the declared
///   set AND the scope is a proper subset of the test tree; a shared
///   write, an unprovable fingerprint, a whole-tree scope, or a missing
///   suite template all select the EXISTING full-suite path. An empty
///   importer set selects the post-run transcript mode (the #741
///   zero-extra-spawn contract on the driver path).
///
/// Every fallback is the pre-existing behavior — the trim is an
/// optimization that must never weaken the certification.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The import-closure scope result (see [RecertScope.compute]).
class RecertScopeResult {
  /// The scoped test files, project-relative POSIX, sorted: the own test
  /// plus every `*_test.dart` file whose import closure reaches the
  /// write set.
  final Set<String> inScope;

  /// Every `*_test.dart` file under the project's `test/` tree.
  final int totalTestFiles;

  const RecertScopeResult({
    required this.inScope,
    required this.totalTestFiles,
  });

  /// Whether the scope covers every test file — the trimmed set IS the
  /// full suite, so running it separately buys nothing (the full-suite
  /// path stays).
  bool get coversWholeTree =>
      totalTestFiles > 0 && inScope.length >= totalTestFiles;
}

/// The import-closure scoping service (spec 1529, FR-8).
class RecertScope {
  /// Computes the re-certification scope for a write set.
  ///
  /// [writtenFiles] is the DECLARED write set (project-relative POSIX or
  /// absolute paths — normalized here): the files make's plan declares it
  /// will write (the registered subject and test paths). [ownTestPath]
  /// is the behavior's own test — always in scope by definition.
  ///
  /// The traversal walks `lib/` and `test/` `.dart` files, parses
  /// `import` / `export` / `part` URIs, resolves self-package
  /// (`package:<name>/...` → `lib/...`) and relative URIs, and reverse-
  /// reaches every file that transitively depends on the write set. The
  /// scope is the reached `*_test.dart` files plus the own test.
  static Future<RecertScopeResult> compute({
    required String projectRoot,
    required Set<String> writtenFiles,
    required String ownTestPath,
  }) async {
    final files = await _projectDartFiles(projectRoot);
    final testFiles = files.where(_isTestEntrypoint).toSet();
    final selfPackage = await _packageConvention(projectRoot);

    // Reverse edges: target file → the files that depend on it.
    final importersOf = <String, Set<String>>{};
    for (final file in files) {
      for (final resolved in _resolvedImportsOf(
        p.join(projectRoot, file),
        file,
        projectRoot,
        selfPackage,
      )) {
        importersOf.putIfAbsent(resolved, () => <String>{}).add(file);
      }
    }

    String normalize(String path) => _normalizeRelative(path, projectRoot);
    final frontier = writtenFiles.map(normalize).toSet();
    final reached = <String>{...frontier};
    final queue = <String>[...frontier];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final importer in importersOf[current] ?? const <String>{}) {
        if (reached.add(importer)) queue.add(importer);
      }
    }

    final inScope = <String>{
      // The behavior's own test is always in scope — by definition, not
      // by reachability (a registry path with a non-`_test.dart` name
      // still certifies).
      normalize(ownTestPath),
      ...reached.where(_isTestEntrypoint),
    };
    return RecertScopeResult(
      inScope: inScope,
      totalTestFiles: testFiles.length,
    );
  }

  static bool _isTestEntrypoint(String file) =>
      file.startsWith('test/') && file.endsWith('_test.dart');

  static String _normalizeRelative(String path, String projectRoot) {
    final rel = p.isAbsolute(path)
        ? p.relative(path, from: projectRoot)
        : p.normalize(path);
    return rel.replaceAll('\\', '/');
  }

  /// Every `.dart` file under `lib/` and `test/`, project-relative POSIX,
  /// sorted (deterministic traversal). Hidden directories and build
  /// output directories are skipped.
  static Future<Set<String>> _projectDartFiles(String projectRoot) async {
    final files = <String>{};
    for (final rootName in const ['lib', 'test']) {
      final dir = Directory(p.join(projectRoot, rootName));
      if (!dir.existsSync()) continue;
      final stream = dir.list(recursive: true, followLinks: false);
      await for (final entity in stream) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: projectRoot);
        final parts = p.split(relative);
        if (parts.any(
          (segment) =>
              segment.startsWith('.') ||
              segment == 'build' ||
              segment == '.dart_tool',
        )) {
          continue;
        }
        if (!relative.endsWith('.dart')) continue;
        files.add(relative.replaceAll('\\', '/'));
      }
    }
    return files;
  }

  /// The project's package name from `pubspec.yaml` (null when absent) —
  /// the key that resolves `package:<name>/...` URIs to `lib/...`.
  static Future<String?> _packageConvention(String projectRoot) async {
    try {
      final raw = await File(
        p.join(projectRoot, 'pubspec.yaml'),
      ).readAsString();
      final match = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(raw);
      return match?.group(1);
    } on FileSystemException {
      return null;
    }
  }

  /// The project-local files [file] depends on, via `import`, `export`,
  /// and `part` URIs. External packages and SDK URIs resolve to nothing.
  static Set<String> _resolvedImportsOf(
    String absolutePath,
    String relativePath,
    String projectRoot,
    String? selfPackage,
  ) {
    final resolved = <String>{};
    String? content;
    try {
      content = File(absolutePath).readAsStringSync();
    } on FileSystemException {
      return resolved;
    }
    final matches = RegExp(
      r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
      multiLine: true,
    ).allMatches(content);
    for (final match in matches) {
      final uri = match.group(1)!;
      final target = _resolveUri(
        uri: uri,
        importerRelativeDir: p.dirname(relativePath),
        selfPackage: selfPackage,
      );
      if (target != null) resolved.add(target);
    }
    return resolved;
  }

  /// Resolves one import URI to a project-relative POSIX path, or null
  /// when it does not name a project file.
  static String? _resolveUri({
    required String uri,
    required String importerRelativeDir,
    required String? selfPackage,
  }) {
    if (uri.startsWith('dart:')) return null;
    if (uri.startsWith('package:')) {
      final rest = uri.substring('package:'.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) return null;
      final pkg = rest.substring(0, slash);
      if (selfPackage == null || pkg != selfPackage) return null;
      return p.posix.normalize('lib/${rest.substring(slash + 1)}');
    }
    final joined = p.posix
        .normalize(p.posix.join(importerRelativeDir, uri))
        .replaceAll('\\', '/');
    if (joined.startsWith('../') || joined == '..') return null;
    return joined;
  }
}

/// A file's stat stamp for the write probe (mtime + size — mtime alone
/// can miss same-second writes, size catches most of those).
class SourceStamp {
  final DateTime modified;
  final int size;

  const SourceStamp({required this.modified, required this.size});
}

/// The untouched-rest proof's observation half (spec 1529, FR-9b): a
/// stat-only snapshot of every project `.dart` file under `lib/` and
/// `test/`, taken BEFORE the pipeline runs and diffed after. Stat-only:
/// the probe never reads or writes project files.
class SourceWriteProbe {
  /// Captures the BEFORE snapshot. Returns an empty map when the project
  /// has no `lib/`/`test/` tree (the diff then proves nothing — the
  /// caller's decision fails closed).
  static Future<Map<String, SourceStamp>> capture({
    required String projectRoot,
  }) async {
    final stamps = <String, SourceStamp>{};
    for (final file in await RecertScope._projectDartFiles(projectRoot)) {
      try {
        final stat = File(p.join(projectRoot, file)).statSync();
        stamps[file] = SourceStamp(modified: stat.modified, size: stat.size);
      } on FileSystemException {
        // A raced deletion: record nothing — a post-diff reappearance
        // counts as a NEW file (conservative).
      }
    }
    return stamps;
  }

  /// The files changed, added, or deleted since [before] — project-
  /// relative POSIX. Deletions count as changes (conservative: a deleted
  /// shared file affects every importer).
  static Future<Set<String>> changedSince({
    required String projectRoot,
    required Map<String, SourceStamp> before,
  }) async {
    final changed = <String>{};
    final seen = <String>{};
    for (final file in await RecertScope._projectDartFiles(projectRoot)) {
      seen.add(file);
      final stamp = before[file];
      if (stamp == null) {
        changed.add(file);
        continue;
      }
      try {
        final stat = File(p.join(projectRoot, file)).statSync();
        if (stat.modified.isAfter(stamp.modified) || stat.size != stamp.size) {
          changed.add(file);
        }
      } on FileSystemException {
        changed.add(file);
      }
    }
    // Deletions: present before, gone now.
    changed.addAll(before.keys.where((f) => !seen.contains(f)));
    return changed;
  }
}

/// How the guard certifies this make (see [planGuardRecert]).
enum RecertGuardMode {
  /// The post-generation single-test transcript certifies (the #741
  /// zero-extra-spawn contract; the importer set is empty).
  postRunTranscript,

  /// ONE scoped suite run over the trimmed set (the #1374
  /// template-append pattern).
  scopedRun,

  /// The existing full-suite guard path — every unmet trim condition
  /// lands here (fail-closed).
  fullSuite,
}

/// The guard's re-certification plan (see [planGuardRecert]).
class RecertGuardPlan {
  final RecertGuardMode mode;

  /// The scoped suite command (`$suiteTemplate <files...>`, files
  /// sorted) — [RecertGuardMode.scopedRun] only.
  final String? command;

  /// The scoped test files, sorted — [RecertGuardMode.scopedRun] only.
  final List<String> files;

  /// The diagnosable reason the mode was selected (printed by the
  /// caller; a decision the operator can audit).
  final String reason;

  const RecertGuardPlan({
    required this.mode,
    this.command,
    this.files = const [],
    required this.reason,
  });
}

/// The fail-closed guard decision (spec 1529, FR-9/FR-10/FR-11).
///
/// The scoped run is selected ONLY when ALL of the following hold:
///
/// 1. [fingerprintProven] — the baseline's dependency fingerprint was
///    computable and matches a fresh computation (the environment is the
///    one the baseline certified);
/// 2. [writesDeclaredOnly] — the write probe proved make changed no
///    `.dart` file outside the declared write set;
/// 3. [scope] does NOT cover the whole tree (a whole-tree scope IS the
///    full suite — the existing path runs, byte-identical behavior for
///    small/fast suites);
/// 4. the importer set is non-empty (an empty set means the behavior's
///    own test is the only affected test — the post-run transcript mode);
/// 5. [suiteTemplate] is present (the scoped command cannot be built
///    without it).
///
/// Every violated condition selects [RecertGuardMode.fullSuite] — the
/// EXISTING behavior — never a weaker certification.
RecertGuardPlan planGuardRecert({
  required bool fingerprintProven,
  required bool writesDeclaredOnly,
  required RecertScopeResult scope,
  required String ownTestPath,
  String? suiteTemplate,
}) {
  if (!fingerprintProven) {
    return const RecertGuardPlan(
      mode: RecertGuardMode.fullSuite,
      reason:
          'the dependency fingerprint is not provable '
          '(missing, unrecorded, or changed since the baseline)',
    );
  }
  if (!writesDeclaredOnly) {
    return const RecertGuardPlan(
      mode: RecertGuardMode.fullSuite,
      reason: 'the generation wrote file(s) outside the declared set',
    );
  }
  if (scope.coversWholeTree) {
    return const RecertGuardPlan(
      mode: RecertGuardMode.fullSuite,
      reason: 'every test is in scope — the full suite IS the trimmed set',
    );
  }
  if (scope.inScope.length <= 1) {
    return const RecertGuardPlan(
      mode: RecertGuardMode.postRunTranscript,
      reason:
          'no other test imports the written files — the '
          'post-generation single-test transcript certifies with zero '
          'extra spawns',
    );
  }
  if (suiteTemplate == null || suiteTemplate.isEmpty) {
    return const RecertGuardPlan(
      mode: RecertGuardMode.fullSuite,
      reason: 'no suite template — the scoped command cannot be built',
    );
  }
  final files = scope.inScope.toList()..sort();
  return RecertGuardPlan(
    mode: RecertGuardMode.scopedRun,
    command: '$suiteTemplate ${files.join(' ')}',
    files: files,
    reason:
        'the import closure of the declared write set reaches '
        '${files.length} test file(s)',
  );
}
