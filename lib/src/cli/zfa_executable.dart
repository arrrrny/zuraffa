/// The compiled-child contract for every `zfa` subprocess (no-JIT policy).
///
/// Every child the CLI spawns for itself — the TDD step children
/// (`zfa tdd gen|verify-red|make|refactor`), the corpus harness's
/// `zfa tdd run|verify`, the refactor build pass, the dream runner, the
/// differential ref worktree, the replayed history — must be a COMPILED
/// binary. Spawning `dart <path>/bin/zfa.dart` pays the Dart VM front-end
/// + JIT compile of the whole package before the child runs a single
/// command (issue #531 measured ~20s cold per spawn; the differential and
/// corpus harnesses spawn dozens), and it makes every child's behavior
/// depend on the child-side tree rather than the tree that is driving.
///
/// So when the driver itself is running from source, the source is AOT
/// compiled ONCE into `<sourceRoot>/.dart_tool/zfa_cli_bin/zfa_exe` and
/// every child spawns that artifact. The cache is shared with
/// `test/helpers/run_zfa_source.dart` on purpose: tests and runtime use
/// the same binary, so a warm cache is warm for both.
///
/// Failures are LOUD. A compile that cannot happen throws
/// [ZfaCompilationException] instead of degrading to a JIT spawn — the
/// degraded path is exactly what the policy exists to remove. The single
/// escape hatch is `ZFA_ALLOW_JIT=1`, read per call, for environments that
/// genuinely cannot run `dart compile exe` (see [kZfaAllowJitEnv]).
///
/// Related history: the entrypoint tiers that made a source `bin/zfa.dart`
/// win over the system binary are #665/#690 (`PipelineRunner` /
/// `StepRunner`), the stale-system-install pin is #1472, the staleness
/// warning is #1184, and the ETXTBSY race the atomic rename fixes is #644.
///
/// Issue #1664: the compile itself is the last place a current compiled
/// binary can be overlooked. The #1643/#1645 running-binary tiers fix WHICH
/// candidate the resolution chains pick when the driver is compiled, but a
/// resolution that still lands on a source `bin/zfa.dart` (the shape an
/// installed binary whose AOT runtime bakes the source script path into
/// `Platform.script` produces) was compiled unconditionally on cache
/// miss/stale — and `scripts/rebuild.sh` wipes `.dart_tool` on every
/// install, so the miss recurs after every master bump (~85s inside the
/// first refactor). Now the cache-miss path first asks
/// [ZfaExecutable.currentInstalledBinary]: when the RUNNING process is a
/// compiled (non-VM) executable whose `zfa.build_commit` equals the
/// candidate source root's git HEAD, that binary IS the artifact the
/// compile would rebuild, and it is returned instead. A marker that
/// disagrees (or any unprovable input) falls through to the compile.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'binary_staleness.dart' show isVmExecutableName, zfaBuildCommitMarker;

/// The ONE explicit JIT escape hatch. When it is exactly `1`, a `.dart`
/// entrypoint is spawned through the Dart VM (the pre-policy behavior) and
/// one loud warning line is printed. Any other value — including unset —
/// keeps the compiled-child policy in force. Default off.
const String kZfaAllowJitEnv = 'ZFA_ALLOW_JIT';

/// Timeout scale for subprocess budgets (issue #1187), read per call so a
/// test can pass its own environment map. Missing / unparsable / non-finite
/// / below-1.0 values read as 1.0 — the scale only ever RELAXES a budget.
const String kZfaTimeoutScaleEnv = 'ZFA_TEST_TIMEOUT_SCALE';

/// Base AOT compile budget before the scale (issue #1187: the 2019 Intel
/// Mac baseline's cold frontend compile can exceed the bare 100s).
const Duration kZfaCompileBaseTimeout = Duration(seconds: 100);

/// Directory (relative to the source root) holding the compiled entrypoint
/// and its build lock — the same location `run_zfa_source.dart` uses.
const List<String> kZfaBinaryCacheDir = ['.dart_tool', 'zfa_cli_bin'];

/// File name of the cached compiled entrypoint inside
/// [kZfaBinaryCacheDir].
const String kZfaBinaryName = 'zfa_exe';

/// File name of the write-then-rename staging sibling of
/// [kZfaBinaryName] (the ETXTBSY guard, issue #644).
const String kZfaBinaryTmpName = 'zfa_exe.tmp';

/// File name of the advisory build lock inside [kZfaBinaryCacheDir].
const String kZfaBuildLockName = 'build.lock';

/// The default `git rev-parse HEAD` runner for the #1664 reuse probe —
/// deliberately SEPARATE from the compile runner ([ZfaCompileRunner] sites
/// inject a compiler fake that records argv; the probe's git argv must
/// never ride it).
Future<ProcessResult> _defaultGitProbe(
  List<String> argv,
  String workingDirectory,
) => Process.run(
  argv.first,
  argv.skip(1).toList(),
  workingDirectory: workingDirectory,
);

/// Runs one compiler command in [workingDirectory]. Injectable so unit
/// tests never invoke a real `dart compile exe`.
typedef ZfaCompileRunner =
    Future<ProcessResult> Function(List<String> argv, String workingDirectory);

/// Runs the reuse probe's ONE git command (`git rev-parse HEAD`) in
/// [workingDirectory]. Deliberately a SEPARATE typedef from
/// [ZfaCompileRunner] so the type system enforces the design note below:
/// a compiler fake cannot be handed to the probe and polluted with git
/// argv — that misuse is now a compile error, not a latent test bug.
/// Structurally identical to [ZfaCompileRunner], so existing fakes keep
/// compiling.
typedef ZfaGitRunner =
    Future<ProcessResult> Function(List<String> argv, String workingDirectory);

/// The `ensureCompiled` seam every spawn site takes: resolves a candidate
/// entrypoint to something runnable (a `.dart` candidate becomes the
/// compiled artifact unless the JIT escape hatch is set). Defaults to
/// [ZfaExecutable.ensureCompiled].
typedef ZfaEnsureCompiled =
    Future<String> Function(
      String candidate, {
      String? sourceRoot,
      ZfaCompileRunner? runner,
      Map<String, String>? environment,
    });

/// A compile that could not produce a usable artifact — non-zero exit, a
/// deadline kill, or a missing output file. Carries everything the
/// operator needs to reproduce by hand; there is deliberately NO fallback.
class ZfaCompilationException implements Exception {
  ZfaCompilationException({
    required this.reason,
    required this.command,
    required this.exitCode,
    this.stderrTail = '',
  });

  /// Why the compile was refused (`dart compile exe` failed / timed out /
  /// produced no output).
  final String reason;

  /// The exact command line that was attempted, for a copy-paste repro.
  final String command;

  /// The compile child's exit code (`-1` for a deadline kill).
  final int exitCode;

  /// The last ~20 lines of the compile child's stderr (or stdout when
  /// stderr was empty), so the real compiler error is visible.
  final String stderrTail;

  @override
  String toString() {
    final tail = stderrTail.trimRight();
    return 'ZfaCompilationException: $reason (exit $exitCode)\n'
        '  command: $command'
        '${tail.isEmpty ? '' : '\n  stderr:\n$tail'}';
  }
}

/// Resolution + AOT-compilation of the zfa entrypoint (the no-JIT policy).
///
/// The API is static and side-effect free apart from the cache it writes:
/// no process-global mutable state, so parallel test files and nested CLI
/// runs contend only through the on-disk `build.lock`.
class ZfaExecutable {
  const ZfaExecutable._();

  /// The default compile runner — the real `dart compile exe`. Memoized as
  /// a static final (a constant, not mutable state) so callers pay no
  /// closure allocation per call.
  static final ZfaCompileRunner _defaultCompile = _runCompiler;

  /// Whether [path] names a Dart SOURCE entrypoint (the JIT shape the
  /// policy removes). Anything else — a compiled executable, a snapshot, a
  /// scripted fake bin (`--zfa-bin` test fixtures) — spawns directly.
  static bool isDartScript(String path) => path.endsWith('.dart');

  /// The argv for a zfa child: `[entry, ...args]` for a compiled entrypoint,
  /// `['dart', entry, ...args]` ONLY under the JIT escape hatch, and a
  /// [StateError] otherwise.
  ///
  /// Every spawn site shapes its child argv through this, so the `dart`
  /// prefix cannot survive anywhere except [kZfaAllowJitEnv] — the reason
  /// `test/core/no_jit_zfa_spawn_scan_test.dart` can assert the sweep.
  static List<String> commandFor(
    String entry,
    List<String> args, {
    Map<String, String>? environment,
  }) {
    if (!isDartScript(entry)) return [entry, ...args];
    final env = environment ?? Platform.environment;
    if (env[kZfaAllowJitEnv] == '1') return ['dart', entry, ...args];
    throw StateError(
      'refusing to spawn the zfa CLI in JIT mode: "$entry" is a Dart source '
      'entrypoint and no compiled artifact was used. Every zfa child must be '
      'a compiled binary — resolve the entrypoint through '
      'ZfaExecutable.ensureCompiled, or set $kZfaAllowJitEnv=1 in a degraded '
      'environment that cannot run `dart compile exe`.',
    );
  }

  /// Resolve [candidate] to a spawnable entrypoint.
  ///
  /// - a non-`.dart` candidate (compiled exe, snapshot, scripted fake bin)
  ///   is returned UNCHANGED — the `--zfa-bin` test fixtures depend on it;
  /// - a `.dart` candidate under [kZfaAllowJitEnv] is returned unchanged
  ///   after ONE loud warning line (the only JIT path);
  /// - otherwise the candidate is AOT compiled (once) into
  ///   `<sourceRoot>/.dart_tool/zfa_cli_bin/` and that artifact is
  ///   returned. A compile that fails, times out, or produces nothing
  ///   throws [ZfaCompilationException] — never a silent JIT fallback.
  ///
  /// [sourceRoot] defaults to the root [sourceRootOf] derives — the
  /// `<root>` of a canonical `bin/zfa.dart` / `bin/zuraffa.dart`
  /// candidate, or the nearest package root above any other `.dart`
  /// candidate — and, for a standalone script outside every package, to
  /// the candidate's own directory. An explicit `--zfa-bin <path>.dart` is
  /// therefore compiled like any other source entrypoint: no caller has to
  /// pass a parameter the flag cannot reach.
  ///
  /// [runner] replaces the real compiler (unit-test seam); [environment]
  /// replaces `Platform.environment` for both the escape hatch and the
  /// issue #1187 timeout scale; [runningExecutable] stands in for
  /// `Platform.resolvedExecutable` in the #1664 reuse probe so tests can
  /// drive a fake COMPILED parent through this public seam (the production
  /// wiring otherwise reads the driver inline and has no hermetic
  /// compiled-parent shape).
  static Future<String> ensureCompiled(
    String candidate, {
    String? sourceRoot,
    ZfaCompileRunner? runner,
    Map<String, String>? environment,
    String? runningExecutable,
  }) async {
    if (!isDartScript(candidate)) return candidate;
    final env = environment ?? Platform.environment;
    if (env[kZfaAllowJitEnv] == '1') {
      // The ONE JIT path: loud, single-line, and never silent.
      print(
        '⚠️  $kZfaAllowJitEnv=1 — spawning $candidate through the Dart VM '
        '(JIT); the no-JIT policy requires a compiled zfa.',
      );
      return candidate;
    }
    final root =
        sourceRoot ?? sourceRootOf(candidate) ?? _anchorDirOf(candidate);
    return _compileCached(
      candidate: candidate,
      sourceRoot: root,
      runner: runner ?? _defaultCompile,
      environment: env,
      runningExecutable: runningExecutable,
    );
  }

  /// The running binary to reuse for children in place of a compile, or
  /// null when the reuse is unproven and the compile must happen (issue
  /// #1664).
  ///
  /// The probe fires only when ALL of the following hold:
  ///
  /// - [candidate] is the canonical package entrypoint of [sourceRoot]
  ///   (`bin/zfa.dart` / `bin/zuraffa.dart`) — the shape that shares the
  ///   [kZfaBinaryName] cache slot. A custom `--zfa-bin <path>.dart`
  ///   fixture keeps its own artifact: replacing a scripted entrypoint
  ///   with the zfa binary would change what the child runs.
  /// - [runningExecutable] is a compiled (non-Dart-VM) executable that
  ///   exists on disk. VM drivers (`dart run`, `dart test`, a
  ///   `dartaotruntime` snapshot launch) are rejected before any probe
  ///   work: a source/test context must keep the compile-cache contract
  ///   (the artifact tests and runtime share).
  /// - `<dirname(runningExecutable)>/zfa.build_commit` (the marker
  ///   `scripts/rebuild.sh` records at install time) exists and is
  ///   non-empty. No marker — a pre-#1184 install, the `scripts/zfa`
  ///   compile-cache artifact — leaves staleness unprovable.
  /// - `git rev-parse HEAD` in [sourceRoot] resolves (via [runner]) and
  ///   EQUALS the marker commit. A mismatch proves the installed binary
  ///   predates the checkout's current source — the stale-reuse guard
  ///   (acceptance criterion 3) — and a failed/empty HEAD fails open to
  ///   the compile.
  ///
  /// When every condition holds, the running binary IS the artifact the
  /// compile would rebuild (same source commit), and returning it skips
  /// the one-time ~85s AOT build that otherwise lands inside the first
  /// refactor after every master bump. Fully injectable ([runner] replaces
  /// the git probe, [runningExecutable] stands in for
  /// `Platform.resolvedExecutable`) so tests exercise every branch
  /// hermetically.
  static Future<String?> currentInstalledBinary({
    required String candidate,
    required String sourceRoot,
    required String runningExecutable,
    ZfaGitRunner? runner,
  }) async {
    if (!_isCanonicalEntrypoint(candidate, sourceRoot)) return null;
    if (_isVmExecutablePath(runningExecutable)) return null;
    final exe = File(runningExecutable);
    if (!exe.existsSync()) return null;
    final marker = File(p.join(p.dirname(exe.path), zfaBuildCommitMarker));
    final String commit;
    try {
      if (!marker.existsSync()) return null;
      commit = marker.readAsStringSync().trim();
    } on IOException {
      return null;
    }
    if (commit.isEmpty) return null;
    final String head;
    try {
      final result = await (runner ?? _defaultGitProbe)([
        'git',
        'rev-parse',
        'HEAD',
      ], sourceRoot);
      if (result.exitCode != 0) return null;
      head = '${result.stdout}'.trim();
    } on Object {
      return null;
    }
    if (head.isEmpty) return null;
    // Strict full-SHA equality: `scripts/rebuild.sh` records the full
    // `git rev-parse HEAD` output, and anything else (a short form, a
    // different tree's commit) must not pass on the strength of a prefix.
    return commit == head ? exe.path : null;
  }

  /// Whether [path] names a Dart VM executable rather than a compiled zfa
  /// binary — [isVmExecutableName] (`binary_staleness.dart`), the SAME
  /// exclusion `BinaryStaleness.binaryDir` applies, shared rather than
  /// duplicated so the two predicates cannot diverge. A VM driver must
  /// never reuse an installed binary: source/test contexts compile the
  /// driven tree into the shared cache.
  static bool _isVmExecutablePath(String path) =>
      isVmExecutableName(p.basename(path));

  /// The source root that anchors [candidate]'s compile cache, or null when
  /// the candidate sits inside no Dart package at all.
  ///
  ///   1. the canonical `<root>/bin/zfa.dart` / `<root>/bin/zuraffa.dart`
  ///      entrypoint shape → `<root>`;
  ///   2. any other `.dart` candidate — an explicit `--zfa-bin <path>.dart`
  ///      override — → the nearest ancestor holding a `pubspec.yaml`, so
  ///      the override is compiled against its own package.
  ///
  /// Both shapes are DERIVED here rather than demanded from the caller:
  /// `--zfa-bin` is the only way an operator hands over a source
  /// entrypoint, none of its call sites can pass a `sourceRoot`, and a
  /// refusal would abort a documented flag with a remedy the flag cannot
  /// express.
  static String? sourceRootOf(String candidate) {
    final normalized = p.normalize(candidate);
    final base = p.basename(normalized);
    if (base == 'zfa.dart' || base == 'zuraffa.dart') {
      final dir = p.dirname(normalized);
      if (p.basename(dir) == 'bin') return p.dirname(dir);
    }
    return _packageRootAbove(normalized);
  }

  /// The last-resort anchor for a `.dart` candidate with no package root
  /// above it: a standalone script is still COMPILED (never spawned through
  /// the VM) against its own directory.
  static String _anchorDirOf(String candidate) =>
      p.dirname(p.absolute(p.normalize(candidate)));

  /// The nearest ancestor of [candidate] carrying a `pubspec.yaml`, or null
  /// when the path lives outside every Dart package.
  static String? _packageRootAbove(String candidate) {
    var dir = p.dirname(p.absolute(p.normalize(candidate)));
    while (true) {
      if (File(p.join(dir, 'pubspec.yaml')).existsSync()) return dir;
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
  }

  /// Whether [candidate] is the canonical package entrypoint of
  /// [sourceRoot] — the one shape that shares the [kZfaBinaryName] cache
  /// slot with `scripts/zfa` and `test/helpers/run_zfa_source.dart`.
  static bool _isCanonicalEntrypoint(String candidate, String sourceRoot) {
    final normalized = p.normalize(candidate);
    if (p.dirname(normalized) != p.normalize(p.join(sourceRoot, 'bin'))) {
      return false;
    }
    final base = p.basename(normalized);
    return base == 'zfa.dart' || base == 'zuraffa.dart';
  }

  /// A short, stable digest of [text] (FNV-1a, 8 hex chars): enough to give
  /// each explicit `--zfa-bin` source its own cache slot without pulling a
  /// crypto package into a pure service.
  static String _shortDigest(String text) {
    var hash = 0xcbf29ce484222325;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash
        .toUnsigned(64)
        .toRadixString(16)
        .padLeft(16, '0')
        .substring(0, 8);
  }

  /// Compile [candidate] into the shared cache, reusing a fresh artifact.
  static Future<String> _compileCached({
    required String candidate,
    required String sourceRoot,
    required ZfaCompileRunner runner,
    required Map<String, String> environment,
    String? runningExecutable,
  }) async {
    final cacheDir = Directory(
      p.join(sourceRoot, p.joinAll(kZfaBinaryCacheDir)),
    );
    // One slot per entrypoint. The canonical package entrypoint keeps the
    // shared [kZfaBinaryName] artifact — `scripts/zfa` and
    // `test/helpers/run_zfa_source.dart` reuse that exact path — while any
    // other explicit source entrypoint gets its own slot: two `--zfa-bin`
    // overrides inside one package must never inherit each other's binary.
    final exeName = _isCanonicalEntrypoint(candidate, sourceRoot)
        ? kZfaBinaryName
        : '${kZfaBinaryName}_${_shortDigest(p.normalize(candidate))}';
    final exePath = p.join(cacheDir.path, exeName);
    final exeFile = File(exePath);

    if (exeFile.existsSync() && !_isStale(exeFile, candidate, sourceRoot)) {
      return exePath;
    }

    // Issue #1664: the cache is missing or stale — the moment the old path
    // paid the one-time ~85s `dart compile exe` after every master bump
    // (rebuild.sh wipes `.dart_tool`, so the miss recurs per install).
    // When the RUNNING process is itself a compiled install proven current
    // for this source tree (`.build_commit` == checkout HEAD), that binary
    // is exactly what the compile would rebuild: reuse it instead. The
    // fresh-cache verdict above stays first, so the warm-cache steady
    // state is unchanged; a null probe (VM driver, no/unreadable marker,
    // git failure, commit mismatch, non-canonical candidate) falls
    // through to the compile path unchanged.
    final installed = await currentInstalledBinary(
      candidate: candidate,
      sourceRoot: sourceRoot,
      runningExecutable: runningExecutable ?? Platform.resolvedExecutable,
    );
    if (installed != null) {
      // The commit-equality guard proves the COMMIT, not the working tree:
      // when the cache is missing/stale BECAUSE OF uncommitted edits under
      // [sourceRoot], children would silently run pre-edit code. One
      // advisory line on the #1184 warning channel (stderr) makes that
      // "why doesn't my child see my edit" case self-answering.
      stderr.writeln(
        'zfa: children reuse installed binary $installed '
        '(zfa.build_commit == HEAD); uncommitted edits under '
        '$sourceRoot are NOT included — re-run scripts/rebuild.sh '
        'to bake them in.',
      );
      return installed;
    }

    await cacheDir.create(recursive: true);

    // Serialize the build across every process that shares this cache: the
    // driver, a nested step child, and parallel `dart test` files all
    // compile into the same path. The losers would otherwise exec a
    // half-written binary (Linux ETXTBSY / "Text file busy" — the failure
    // that killed `zfa feature enable notes` on the CI runner, issue #644)
    // or race the rename.
    RandomAccessFile? lock;
    try {
      lock = await _acquireLock(File(p.join(cacheDir.path, kZfaBuildLockName)));
      // Re-check under the lock: whoever we waited for may have just built.
      if (exeFile.existsSync() && !_isStale(exeFile, candidate, sourceRoot)) {
        return exePath;
      }

      // Build to a temp sibling and rename into place. The kernel refuses to
      // exec a file that is still being written, and the final path must
      // appear fully-formed or not at all (issue #644) — a concurrent
      // spawner therefore never lands on a partially written binary.
      final tmpPath = p.join(cacheDir.path, '$exeName.tmp');
      final tmpFile = File(tmpPath);
      if (tmpFile.existsSync()) tmpFile.deleteSync();

      final argv = ['dart', 'compile', 'exe', candidate, '--output', tmpPath];
      final ProcessResult result;
      try {
        result = await runner(
          argv,
          sourceRoot,
        ).timeout(_compileTimeout(environment));
      } on TimeoutException {
        if (tmpFile.existsSync()) tmpFile.deleteSync();
        throw ZfaCompilationException(
          reason:
              'dart compile exe exceeded its '
              '${_compileTimeout(environment).inSeconds}s budget (raise it '
              'with $kZfaTimeoutScaleEnv)',
          command: argv.join(' '),
          exitCode: -1,
        );
      }

      if (result.exitCode != 0) {
        if (tmpFile.existsSync()) tmpFile.deleteSync();
        throw ZfaCompilationException(
          reason: 'dart compile exe failed for "$candidate"',
          command: argv.join(' '),
          exitCode: result.exitCode,
          stderrTail: _tail(
            '${result.stderr}'.trim().isEmpty
                ? '${result.stdout}'
                : '${result.stderr}',
          ),
        );
      }
      if (!tmpFile.existsSync()) {
        throw ZfaCompilationException(
          reason:
              'dart compile exe reported success but wrote no artifact at '
              '"$tmpPath"',
          command: argv.join(' '),
          exitCode: 0,
          stderrTail: _tail('${result.stderr}'),
        );
      }
      tmpFile.renameSync(exePath);
      return exePath;
    } finally {
      await lock?.close();
    }
  }

  /// True when [exeFile] is older than the entrypoint source, any file under
  /// the source root's `lib/`, `pubspec.yaml`, or `pubspec.lock` — i.e. the
  /// cached binary no longer reflects this tree.
  static bool _isStale(File exeFile, String candidate, String sourceRoot) {
    final builtAt = exeFile.lastModifiedSync();
    for (final path in [
      candidate,
      p.join(sourceRoot, 'pubspec.yaml'),
      p.join(sourceRoot, 'pubspec.lock'),
    ]) {
      final file = File(path);
      if (file.existsSync() && file.lastModifiedSync().isAfter(builtAt)) {
        return true;
      }
    }
    final libDir = Directory(p.join(sourceRoot, 'lib'));
    if (libDir.existsSync()) {
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.lastModifiedSync().isAfter(builtAt)) {
          return true;
        }
      }
    }
    return false;
  }

  /// The compile budget: [kZfaCompileBaseTimeout] scaled by
  /// [kZfaTimeoutScaleEnv] (issue #1187). Garbage — unparsable, NaN,
  /// infinite, below 1.0 — reads as 1.0 rather than poisoning the budget.
  static Duration _compileTimeout(Map<String, String> environment) {
    final raw = environment[kZfaTimeoutScaleEnv]?.trim();
    final parsed = raw == null ? null : double.tryParse(raw);
    final scale = (parsed == null || !parsed.isFinite || parsed < 1.0)
        ? 1.0
        : parsed;
    return Duration(
      milliseconds: (kZfaCompileBaseTimeout.inMilliseconds * scale).round(),
    );
  }

  /// Acquire an exclusive advisory lock on [lockFile] (POSIX `flock`), so the
  /// lock dies with the process rather than needing cleanup after a crash.
  static Future<RandomAccessFile> _acquireLock(File lockFile) async {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (true) {
      RandomAccessFile? file;
      try {
        file = await lockFile.open(mode: FileMode.write);
        file.lockSync();
        return file;
      } on Object {
        await file?.close();
        // `flock` on an already-locked file throws on some platforms; a
        // filesystem without FileLock support throws always. Both retry:
        // the lock is a contention optimization, not a correctness gate —
        // the atomic rename is what keeps a partial binary from being
        // executed (issue #644).
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// The last [lines] lines of [text], so a compiler failure surfaces its
  /// real diagnostic instead of a megabyte of progress spam.
  static String _tail(String text, {int lines = 20}) {
    final all = text.trimRight().split('\n');
    if (all.length <= lines) return all.join('\n');
    return all.sublist(all.length - lines).join('\n');
  }

  static Future<ProcessResult> _runCompiler(
    List<String> argv,
    String workingDirectory,
  ) => Process.run(
    argv.first,
    argv.skip(1).toList(),
    workingDirectory: workingDirectory,
  );
}
