/// Per-run scratch TMPDIR (spec 1520; issue #1520) — the single owner of
/// the scratch contract shared by every tdd command that spawns test
/// children.
///
/// Every `dart test` process creates a per-process
/// `$TMPDIR/dart_test.kernel.<random>/` kernel dir. When the child inherits
/// the ambient user TMPDIR, that dir lands in storage shared by every agent
/// and terminal on the machine — where any agent's #1507 janitor sweep can
/// delete another agent's actively-compiling kernel. The fix is isolation
/// by construction:
///
/// 1. [ScratchTmpDir.acquire] creates ONE scratch dir per command
///    invocation (`zfa-<feature>-<random>` via `createTemp`);
/// 2. [ScratchTmpDir.childEnvironment] injects it as `TMPDIR`/`TEMP`/`TMP`
///    into every child's environment (through `runTimed`'s `environment`
///    parameter and the spawn sites' default spawners);
/// 3. [ScratchTmpDir.dispose] deletes the run's own scratch recursively,
///    best-effort, at run end — the #1507 leak is fixed by construction
///    because the run deletes ONLY its own scratch.
///
/// Root resolution ([configuredRoot], FR-6): the `ZFA_TMPDIR` environment
/// variable (invocation-level) wins over the `.zfa.json` `tdd.tmpDir` key
/// (project-level); absent both, the scratch root is the environment's
/// effective temp root (TMPDIR/TEMP/TMP, else `Directory.systemTemp`). The
/// effective-temp-root default is what makes nesting work (FR-4): a spawned
/// tdd command inherits its parent's scratch as TMPDIR, so ITS
/// `Directory.systemTemp` resolves inside the parent's scratch — children
/// never escape the outermost scratch even when they create scratches of
/// their own.
///
/// Everything is best-effort: [acquire] returns null instead of throwing,
/// and [dispose] swallows filesystem errors — a scratchless run (children
/// inherit the ambient TMPDIR, the janitor cleans historical leaks) always
/// beats a crashed command.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The per-run scratch name prefix — `zfa-<label>-<createTemp random>`.
const String defaultScratchPrefix = 'zfa-';

/// The `.zfa.json` key holding the project-level scratch root:
/// `{"tdd": {"tmpDir": "<root>"}}`.
const String scratchTmpDirConfigKey = 'tmpDir';

/// Resolves the configured scratch root (spec 1520 FR-6): `ZFA_TMPDIR`
/// (non-empty) > `.zfa.json` `tdd.tmpDir` (non-empty String) > null (no
/// configured root — use the effective temp root).
///
/// [environment] defaults to [Platform.environment]; [projectRoot] may be
/// null (no `.zfa.json` tier). A malformed `.zfa.json` degrades to null —
/// the config read is best-effort, matching the
/// `tdd.realizeDifferentialThreshold` pattern.
String? scratchConfiguredRoot(
  String? projectRoot, {
  Map<String, String>? environment,
}) {
  final env = environment ?? Platform.environment;
  final viaEnv = env['ZFA_TMPDIR'];
  if (viaEnv != null && viaEnv.isNotEmpty) return viaEnv;
  if (projectRoot == null || projectRoot.isEmpty) return null;
  try {
    final file = File(p.join(projectRoot, '.zfa.json'));
    if (!file.existsSync()) return null;
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map<String, dynamic>) return null;
    final tdd = json['tdd'];
    if (tdd is! Map<String, dynamic>) return null;
    final raw = tdd[scratchTmpDirConfigKey];
    if (raw is String && raw.isNotEmpty) return raw;
    return null;
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
}

/// The effective temp root of [environment] — TMPDIR, then TEMP, then TMP,
/// then `Directory.systemTemp` (the same resolution chain the kernel
/// janitor uses). When [environment] is omitted this is the process's own
/// ambient temp root; when a child's injected environment is passed, this
/// is the parent scratch — the nesting rule behind FR-4.
String scratchEffectiveTempRoot(Map<String, String>? environment) {
  final env = environment ?? Platform.environment;
  return env['TMPDIR'] ??
      env['TEMP'] ??
      env['TMP'] ??
      Directory.systemTemp.path;
}

/// Sanitizes [label] into a safe path segment: every character outside
/// `[A-Za-z0-9._-]` becomes `_`, capped at 80 chars so a hostile feature
/// reference can never escape the root or blow past filename limits.
String sanitizeScratchLabel(String label) {
  final sanitized = label
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'^\.+'), '_');
  if (sanitized.isEmpty) return 'run';
  return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80);
}

/// One command invocation's scratch TMPDIR.
class ScratchTmpDir {
  ScratchTmpDir._(this.dir);

  /// The scratch directory. Created via `createTemp` (random suffix), so
  /// concurrent invocations never collide.
  final Directory dir;

  /// The scratch path ([dir.path]).
  String get path => dir.path;

  /// Acquire the per-run scratch (spec 1520 FR-1): create
  /// `zfa-<label>-<random>` under the configured root ([scratchConfiguredRoot]
  /// — ensured to exist) or, absent a configured root, under the effective
  /// temp root of [environment].
  ///
  /// Returns null on ANY failure (an unusable configured root, a
  /// createTemp error) — the caller runs scratchless (children inherit the
  /// ambient TMPDIR) and the janitor still cleans historical leaks. Never
  /// throws.
  static Future<ScratchTmpDir?> acquire({
    required String label,
    String? projectRoot,
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Platform.environment;
    try {
      final configured = scratchConfiguredRoot(projectRoot, environment: env);
      final Directory root;
      if (configured != null) {
        root = Directory(configured);
        await root.create(recursive: true);
      } else {
        root = Directory(scratchEffectiveTempRoot(env));
      }
      final dir = await root.createTemp(
        '$defaultScratchPrefix${sanitizeScratchLabel(label)}-',
      );
      return ScratchTmpDir._(dir);
    } on FileSystemException {
      return null;
    } on OSError {
      return null;
    }
  }

  /// The child environment for this run's subprocesses: a merged copy of
  /// [base] (default [Platform.environment]) with `TMPDIR`, `TEMP` and
  /// `TMP` pointed at the scratch path (spec 1520 FR-1/FR-2). The merge —
  /// not a replacement — keeps PATH, HOME and every other variable
  /// inherited, exactly like `Process.start`'s
  /// `includeParentEnvironment` does for the remainder.
  Map<String, String> childEnvironment({Map<String, String>? base}) {
    final merged = Map<String, String>.from(base ?? Platform.environment)
      ..['TMPDIR'] = path
      ..['TEMP'] = path
      ..['TMP'] = path;
    return merged;
  }

  /// Best-effort recursive delete at run end (spec 1520 FR-3). Idempotent:
  /// a second call on a vanished scratch is a no-op. A failure is swallowed
  /// — the leftover becomes ordinary garbage the janitor's guards reason
  /// about, never a crashed command.
  Future<void> dispose() async {
    try {
      if (!await dir.exists()) return;
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Best-effort — the next cycle's janitor still reasons about the
      // leftover; the run's outcome is untouched.
    }
  }
}
