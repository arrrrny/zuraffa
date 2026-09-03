/// `PassRegistryTracker` — the pass registry of spec 069-corpus-economics
/// (issue #916): a per-feature record of every registered artifact file
/// (each behavior's test + subject, from `specs/<f>/tdd/artifacts.json`)
/// with its content checksum at the last proof, plus the timestamp of the
/// last FULL-suite proof.
///
/// The registry is what makes INCREMENTAL verification possible:
///
/// - `capture` reads the feature's artifact records and hashes every
///   behavior pair's files (test_path + subject_path,
///   project-relative, sha256);
/// - `delta` diffs a previous state against the current one — the
///   pass-registry-CHANGED files (added / removed / modified);
/// - `coveringTestsFor` maps changed files to the tests that cover them
///   (a changed test covers itself; a changed subject is covered by the
///   behaviors that own it);
/// - `commit` persists the state after a successful proof, stamping
///   `last_full_proof_at` when that proof was the full suite.
///
/// Scope policy (frequency engineering — the full gate still exists):
/// the refactor re-proof runs SCOPED to the tests covering changed
/// registered files when the registry allows it; it escalates to FULL
/// when (a) no registry exists yet (the first proof), (b) a changed
/// file is not owned by the registry (an unregistered file could affect
/// any test — the honest scope is everything), (c) the nightly
/// full-proof window has expired (default 24h), or (d) the operator
/// forced it. A zero delta since the last proof skips the re-proof
/// spawn entirely: the exact file state already carries a green proof,
/// and the full gate still runs at preflight, feature completion, and
/// nightly.
///
/// Storage is fail-safe: a missing, corrupt, or malformed registry
/// yields null on load — the caller falls back to the FULL re-proof
/// (safe failure, never a silent pass — the SuiteGuard/#741 house
/// stance).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'artifact_registry.dart';

/// The persisted state of one feature's pass registry.
class PassRegistryState {
  const PassRegistryState({
    required this.feature,
    required this.files,
    this.lastFullProofAt,
    Map<String, String>? tree,
  }) : tree = tree ?? files;

  /// The feature this registry belongs to.
  final String feature;

  /// Project-relative path -> sha256 hex digest of every REGISTERED
  /// artifact file (each behavior's test + subject) at the last proof.
  /// These are the files a SCOPED re-proof reasons about.
  final Map<String, String> files;

  /// Project-relative path -> sha256 of every file under `test/` and
  /// `lib/` at the last proof (registered or not). The tree delta is
  /// the honest change signal: a change to any UNREGISTERED tree file
  /// escalates the re-proof to FULL (it could affect any test), while
  /// the registry delta alone decides the scoped set.
  final Map<String, String> tree;

  /// ISO-8601 UTC timestamp of the last FULL-suite proof (null before
  /// the first full proof — the nightly window is measured against it).
  final String? lastFullProofAt;

  Map<String, dynamic> toJson() => {
    'feature': feature,
    'files': files,
    if (!identical(tree, files)) 'tree': tree,
    'last_full_proof_at': lastFullProofAt,
  };

  static PassRegistryState? fromJson(Map<String, dynamic> json) {
    final feature = json['feature'];
    final files = json['files'];
    if (feature is! String || files is! Map<String, dynamic>) return null;
    final checksums = <String, String>{};
    for (final entry in files.entries) {
      if (entry.value is! String) return null;
      checksums[entry.key] = entry.value as String;
    }
    final treeRaw = json['tree'];
    Map<String, String>? tree;
    if (treeRaw is Map<String, dynamic>) {
      tree = <String, String>{};
      for (final entry in treeRaw.entries) {
        if (entry.value is! String) return null;
        tree[entry.key] = entry.value as String;
      }
    }
    final stamp = json['last_full_proof_at'];
    return PassRegistryState(
      feature: feature,
      files: checksums,
      tree: tree,
      lastFullProofAt: stamp is String ? stamp : null,
    );
  }
}

/// The diff between two registry states: the pass-registry-changed
/// files (project-relative paths).
class PassRegistryDelta {
  const PassRegistryDelta({
    required this.added,
    required this.removed,
    required this.changed,
  });

  final List<String> added;
  final List<String> removed;
  final List<String> changed;

  bool get isEmpty => added.isEmpty && removed.isEmpty && changed.isEmpty;

  /// Every changed path (added + removed + modified), sorted.
  List<String> get allChanged =>
      {...added, ...removed, ...changed}.toList()..sort();
}

/// What the refactor re-proof decided to run.
class ReproofScope {
  const ReproofScope._({
    required bool full,
    required this.reason,
    required this.testPaths,
    required this.changedFiles,
  }) : _full = full;

  final bool _full;

  /// True: run the full suite template verbatim (no file arguments).
  bool get full => _full;

  /// The machine token for the scope decision: `first-proof`,
  /// `unowned-files`, `nightly-window`, `forced`, `scoped`, or
  /// `no-changes`.
  final String reason;

  /// Scoped mode: the PROJECT-RELATIVE test files to append to the
  /// suite command (the tests covering the changed registered files).
  /// Empty in full/skipped mode.
  final List<String> testPaths;

  /// The pass-registry-changed files the decision reasoned about.
  final List<String> changedFiles;

  /// A scoped scope.
  factory ReproofScope.scoped(List<String> testPaths, List<String> changed) =>
      ReproofScope._(
        full: false,
        reason: 'scoped',
        testPaths: testPaths,
        changedFiles: changed,
      );

  /// A full scope with its escalation reason.
  factory ReproofScope.full(String reason, List<String> changed) =>
      ReproofScope._(
        full: true,
        reason: reason,
        testPaths: const [],
        changedFiles: changed,
      );

  /// The zero-delta skip: nothing to re-prove.
  factory ReproofScope.skipped() => const ReproofScope._(
    full: false,
    reason: 'no-changes',
    testPaths: [],
    changedFiles: [],
  );

  bool get skipped => reason == 'no-changes';
}

class PassRegistryTracker {
  const PassRegistryTracker();

  /// The registry file name inside the feature's `tdd/` directory.
  static const fileName = 'pass-registry.json';

  /// The registry path for a feature directory.
  static String pathFor({required String featureDir}) =>
      p.join(featureDir, 'tdd', fileName);

  /// The default nightly full-proof window: a full re-proof at least
  /// once every 24 hours while the corpus is being driven.
  static const Duration defaultFullProofInterval = Duration(hours: 24);

  /// Load the persisted state. Null when missing, unreadable, corrupt,
  /// or typed wrong — the caller falls back to the full re-proof.
  Future<PassRegistryState?> load(String featureDir) async {
    try {
      final file = File(pathFor(featureDir: featureDir));
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return PassRegistryState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Capture the CURRENT registry state from the artifact records: the
  /// sha256 of every behavior's test and subject file
  /// (project-relative paths) in [files], PLUS the sha256 of every
  /// file under `test/` and `lib/` in [tree] — the honest change
  /// signal (unregistered tree changes escalate the re-proof to FULL).
  /// A registered file missing on disk is absent from `files` — the
  /// diff against the previous state reports it as removed (a deleted
  /// artifact is a real change).
  Future<PassRegistryState> capture({
    required String projectRoot,
    required String featureDir,
  }) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final files = <String, String>{};
    for (final record in records) {
      for (final absolute in [record.testPath, record.subjectPath]) {
        final rel = toRelative(absolute, projectRoot);
        if (rel == null) continue;
        final file = File(absolute);
        if (!file.existsSync()) continue;
        files[rel] = sha256OfFile(file);
      }
    }
    final tree = <String, String>{};
    for (final treeName in const ['test', 'lib']) {
      final dir = Directory(p.join(projectRoot, treeName));
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.join(treeName, p.relative(entity.path, from: dir.path));
        tree[p.normalize(rel)] = sha256OfFile(entity);
      }
    }
    return PassRegistryState(
      feature: p.basename(featureDir),
      files: files,
      tree: tree,
      lastFullProofAt: null,
    );
  }

  /// Map each changed file (project-relative) to the test files
  /// (project-relative) that cover it, resolved from the artifact
  /// records: a changed test file covers itself; a changed subject file
  /// is covered by the test of every behavior owning that subject.
  /// Changed paths with no covering tests are absent from the map.
  Future<Map<String, List<String>>> coveringTestsFor({
    required List<String> changedPaths,
    required String projectRoot,
    required String featureDir,
  }) async {
    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();
    final bySubject = <String, List<String>>{};
    for (final record in records) {
      final subjectRel = toRelative(record.subjectPath, projectRoot);
      final testRel = toRelative(record.testPath, projectRoot);
      if (subjectRel == null || testRel == null) continue;
      bySubject.putIfAbsent(subjectRel, () => []).add(testRel);
    }
    final map = <String, List<String>>{};
    for (final path in changedPaths) {
      if (path.startsWith('test/')) {
        map[path] = [path];
      } else if (bySubject.containsKey(path)) {
        map[path] = bySubject[path]!..sort();
      }
    }
    return map;
  }

  /// Commit the state after a successful proof. [fullProof] stamps
  /// `last_full_proof_at` (the nightly window restarts on full proofs
  /// only — a scoped proof preserves the previous stamp so the window
  /// still expires).
  Future<void> commit({
    required String featureDir,
    required PassRegistryState state,
    required bool fullProof,
    required String proofAt,
  }) async {
    final file = File(pathFor(featureDir: featureDir));
    await file.parent.create(recursive: true);
    final previousStamp = fullProof ? proofAt : _preservedStamp(featureDir);
    final stamped = PassRegistryState(
      feature: state.feature,
      files: state.files,
      tree: state.tree,
      lastFullProofAt: previousStamp,
    );
    // Atomic temp+rename (the #828 house pattern).
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(stamped.toJson()),
    );
    await tmp.rename(file.path);
  }

  /// The stamp a scoped commit preserves: the previously persisted
  /// `last_full_proof_at` when present, else this proof's time (the
  /// first commit always follows a full first proof by construction).
  String? _preservedStamp(String featureDir) {
    try {
      final file = File(pathFor(featureDir: featureDir));
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, dynamic>) return null;
      final stamp = json['last_full_proof_at'];
      return stamp is String ? stamp : null;
    } catch (_) {
      return null;
    }
  }

  /// Diff [previous] against [current] on the FULL test/+lib/ tree:
  /// every path whose checksum changed (added / removed / modified)
  /// since the last proof. This is the pass-registry-changed set the
  /// scope decision reasons about; ownership decides scopeability.
  static PassRegistryDelta delta(
    PassRegistryState previous,
    PassRegistryState current,
  ) => _diffMaps(previous.tree, current.tree);

  static PassRegistryDelta _diffMaps(
    Map<String, String> previousFiles,
    Map<String, String> currentFiles,
  ) {
    final added = <String>[];
    final removed = <String>[];
    final changed = <String>[];
    for (final path in currentFiles.keys) {
      if (!previousFiles.containsKey(path)) {
        added.add(path);
      } else if (previousFiles[path] != currentFiles[path]) {
        changed.add(path);
      }
    }
    for (final path in previousFiles.keys) {
      if (!currentFiles.containsKey(path)) removed.add(path);
    }
    return PassRegistryDelta(
      added: added..sort(),
      removed: removed..sort(),
      changed: changed..sort(),
    );
  }

  /// Decide the re-proof scope for a refactor run (the frequency
  /// engineering contract of spec 069):
  ///
  /// 1. no prior state -> FULL `first-proof` (nothing was ever proven);
  /// 2. zero tree delta -> SKIPPED (the exact file state already carries
  ///    a proof — the re-proof spawn is pure redundancy);
  /// 3. a changed path neither the previous nor the current registry
  ///    owns -> FULL `unowned-files` (unregistered edits can affect any
  ///    test);
  /// 4. [forceFull] -> FULL `forced`;
  /// 5. the nightly window expired -> FULL `nightly-window`;
  /// 6. otherwise -> SCOPED to [coveringTests] (the tests covering the
  ///    changed files, pre-resolved by the caller via
  ///    [coveringTestsFor]).
  static ReproofScope decideScope({
    required PassRegistryState? previous,
    required PassRegistryDelta delta,
    required PassRegistryState current,
    required Map<String, List<String>> coveringTests,
    Duration? fullProofInterval,
    DateTime? now,
    bool forceFull = false,
  }) {
    if (previous == null) {
      return ReproofScope.full('first-proof', delta.allChanged);
    }
    if (delta.isEmpty) {
      return ReproofScope.skipped();
    }
    final owned = {...previous.files.keys, ...current.files.keys};
    if (!delta.allChanged.every(owned.contains)) {
      return ReproofScope.full('unowned-files', delta.allChanged);
    }
    if (forceFull) {
      return ReproofScope.full('forced', delta.allChanged);
    }
    final interval = fullProofInterval ?? defaultFullProofInterval;
    final stamp = previous.lastFullProofAt;
    if (stamp == null || _expired(stamp, interval, now ?? DateTime.now())) {
      return ReproofScope.full('nightly-window', delta.allChanged);
    }
    final tests = <String>{
      for (final paths in coveringTests.values) ...paths,
    }.toList()..sort();
    return ReproofScope.scoped(tests, delta.allChanged);
  }

  /// Whether every changed path is owned by the registry state (a
  /// tracked registered file). Unowned changes escalate to FULL.
  static bool ownsAll(List<String> changedPaths, PassRegistryState state) =>
      changedPaths.every(state.files.containsKey);

  /// Whether the full-proof stamp is older than [interval] at [now].
  static bool _expired(String stamp, Duration interval, DateTime now) {
    final at = DateTime.tryParse(stamp);
    if (at == null) return true;
    return now.difference(at) > interval;
  }

  /// Project-relative form of [absolute] (null when it lives outside
  /// the project root). Relative inputs are normalized as-is.
  static String? toRelative(String absolute, String projectRoot) {
    if (!p.isAbsolute(absolute)) return p.normalize(absolute);
    final rel = p.relative(absolute, from: projectRoot);
    if (rel.startsWith('..')) return null; // outside the project
    return p.normalize(rel);
  }

  /// sha256 hex digest of a file's bytes.
  static String sha256OfFile(File file) =>
      crypto.sha256.convert(file.readAsBytesSync()).toString();
}
