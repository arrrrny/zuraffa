import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zuraffa/src/cli/zfa_executable.dart';

import 'project_root.dart';

/// Path to `bin/zfa.dart` resolved from the zuraffa project root.
///
/// Resolve once per test file via [initZfaSourceBin] (call it from `setUpAll`).
String? zfaSourceBin;

/// Parses the raw `ZFA_TEST_TIMEOUT_SCALE` environment value into the
/// multiplier applied to every subprocess timeout budget in this helper
/// (issue #1187).
///
/// Rules:
/// - missing / blank / unparsable values -> 1.0 (the validated defaults);
/// - `NaN` / infinite values -> 1.0 (they would poison every budget into a
///   hang);
/// - values below 1.0 clamp up to 1.0 — the scale exists to RELAX budgets
///   on slow machines, never to tighten them below what CI validates
///   against.
///
/// Exposed as a pure function so the scale mechanism is unit-testable
/// without spawning a subprocess (see
/// `test/helpers/zfa_test_timeout_scale_test.dart`).
double parseTimeoutScale(String? raw) {
  if (raw == null) return 1.0;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 1.0;
  final value = double.tryParse(trimmed);
  if (value == null || value.isNaN || value.isInfinite) return 1.0;
  if (value < 1.0) return 1.0;
  return value;
}

/// The process-wide timeout scale, read once at isolate start from
/// `ZFA_TEST_TIMEOUT_SCALE` via [parseTimeoutScale].
///
/// Set it to stretch every budget proportionally on slow hardware — e.g.
/// `ZFA_TEST_TIMEOUT_SCALE=2 dart test test/feature_flags --preset=all`
/// doubles the 75s child guard (150s), the 100s AOT compile budget (200s)
/// and every suite `Timeout` built through [scaleDuration] (issue #1187:
/// 2019 Intel Mac baseline, modest CI runners).
final double zfaTestTimeoutScale = parseTimeoutScale(
  Platform.environment['ZFA_TEST_TIMEOUT_SCALE'],
);

/// Stretch [base] by [zfaTestTimeoutScale].
///
/// Use this for suite-level `Timeout` declarations so the enclosing test
/// ceiling grows together with the child guard it supervises — the child
/// guard MUST stay shorter than the enclosing test timeout for its
/// fail-fast diagnostic to fire first (see [runZfaSource]).
Duration scaleDuration(Duration base) =>
    Duration(milliseconds: (base.inMilliseconds * zfaTestTimeoutScale).round());

/// Effective default child budget for [runZfaSource]: 75s x
/// [zfaTestTimeoutScale].
Duration get zfaDefaultChildTimeout =>
    scaleDuration(const Duration(seconds: 75));

/// Effective AOT compile budget for the shared build cache:
/// [kZfaCompileBaseTimeout] (100s) stretched by [zfaTestTimeoutScale] — the
/// same budget `ZfaExecutable.ensureCompiled` derives from the same
/// environment variable (issue #1187).
Duration get zfaCompileTimeout => scaleDuration(kZfaCompileBaseTimeout);

/// Base budget for the FIRST cold source spawn of an isolate (issue #1623).
///
/// Under the documented degraded-environment escape hatch
/// (`ZFA_ALLOW_JIT=1` — the only path that spawns `dart bin/zfa.dart`), the
/// child pays the Dart VM front-end + JIT compile of the whole package
/// before it runs a single command: **84s measured cold start alone** on
/// the host that filed #1623 (`time dart bin/zfa.dart --version` → 1m24s).
/// The 75s default guard cannot cover that, so the first source spawn gets
/// a dedicated budget with ~2.9x headroom over the measurement. 240s also
/// stays BELOW the enclosing const test ceilings at scale 1.0 (B9b's
/// 6-minute `Timeout`, B9's 8-minute ceiling), preserving the
/// guard-fires-before-the-ceiling invariant; higher scales are an explicit
/// operator choice (pair with `--timeout xN`, see `test/README.md`).
const Duration kZfaColdSourceBaseTimeout = Duration(seconds: 240);

/// Effective first cold source spawn budget: [kZfaColdSourceBaseTimeout]
/// (240s) stretched by [zfaTestTimeoutScale]. Like every budget here, the
/// scale only ever RELAXES it (>= 240s at any valid scale).
Duration get zfaColdSourceChildTimeout =>
    scaleDuration(kZfaColdSourceBaseTimeout);

/// The budget a `runZfaSource` spawn spends, derived from the spawn shape
/// (issue #1623). Pure and subprocess-free so the matrix is unit-testable
/// (see `test/helpers/zfa_test_timeout_scale_test.dart`).
///
/// - [explicit] — a caller-passed timeout: returned VERBATIM. Explicit
///   budgets are never auto-scaled (documented in `test/README.md`);
///   callers wanting scale-aware custom budgets use [scaleDuration].
/// - [sourceSpawn] — the resolved entrypoint is a Dart source (the
///   `ZFA_ALLOW_JIT=1` shape, `ZfaExecutable.isDartScript`): its cold JIT
///   start alone can exceed the 75s guard (84s measured, issue #1623).
/// - [coldBudgetAvailable] — the isolate has not spent its first-spawn
///   cold budget yet. Subsequent source spawns ride warm OS/VM caches
///   inside the default guard.
Duration resolveChildTimeout({
  Duration? explicit,
  required bool sourceSpawn,
  required bool coldBudgetAvailable,
}) {
  if (explicit != null) return explicit;
  if (sourceSpawn && coldBudgetAvailable) return zfaColdSourceChildTimeout;
  return zfaDefaultChildTimeout;
}

/// Whether this isolate has already spent its first-cold-source-spawn
/// budget ([kZfaColdSourceBaseTimeout] stretched). Isolate-global like
/// [zfaExePath]: one `initZfaSourceBin` per test file means one cold start
/// per isolate; the DECISION stays pure through [resolveChildTimeout].
bool _zfaColdSourceBudgetSpent = false;

/// The absolute zuraffa project root, resolved once via [initZfaSourceBin].
///
/// Used as the subprocess `workingDirectory` so the child process never
/// inherits a contested / deleted temp dir as its CWD (the commands target
/// their sandbox via an explicit `--root`, so the child CWD is irrelevant to
/// what gets written). Always exists and is never deleted by a test, so it is
/// a safe, hermetic CWD for the child (issue #506).
late String zfaProjectRoot;

/// Compiled AOT executable for `bin/zfa.dart`, resolved once per test file
/// in [initZfaSourceBin] through `ZfaExecutable.ensureCompiled`.
///
/// Every spawned `dart bin/zfa.dart` process paid the cost of the `dart`
/// front-end + JIT compile of the entire zuraffa package before it could run a
/// single command. The `xray` integration group launches the CLI six times; at
/// ~20s of cold compile per spawn that already exceeds the 2-minute *group*
/// timeout on its own (issue #531). Running a precompiled AOT executable
/// instead drops each spawn to milliseconds, which is what makes the group
/// complete well within budget.
///
/// The no-JIT policy keeps this contract in production too: the cache and the
/// freshness rules now live in `lib/src/cli/zfa_executable.dart`, shared with
/// every child the CLI spawns. A build that cannot happen is a hard failure
/// (see [initZfaSourceBin]) — the pre-policy silent `dart bin/zfa.dart`
/// fallback survives only under `ZFA_ALLOW_JIT=1`.
String? zfaExePath;

/// Resolve [zfaSourceBin], [zfaProjectRoot], and [zfaExePath].
///
/// Uses [findProjectRoot], which tolerates a contaminated `Directory.current`
/// (see `test/helpers/project_root.dart`): it only rewrites the process CWD
/// when the current directory is already invalid, never while a valid
/// directory is the process CWD. Call this from `setUpAll` so the per-test
/// bodies never touch the process-global working directory.
///
/// Throws (failing the whole test file loudly) when the AOT build cannot
/// happen and `ZFA_ALLOW_JIT=1` is not set: the no-JIT policy forbids
/// silently degrading every spawn in the file to a slow, JIT-compiled
/// `dart bin/zfa.dart` child.
Future<void> initZfaSourceBin() async {
  final root = await findProjectRoot();
  zfaProjectRoot = root;
  zfaSourceBin = p.join(root, 'bin', 'zfa.dart');
  zfaExePath = await _resolveZfaExecutable();
}

/// The entrypoint every spawn in this helper uses: the shared compiled
/// artifact, or the source path under the explicit `ZFA_ALLOW_JIT=1` escape
/// hatch. A compile failure is never swallowed.
Future<String> _resolveZfaExecutable() async {
  try {
    return await ZfaExecutable.ensureCompiled(zfaSourceBin!);
  } on ZfaCompilationException catch (e) {
    throw StateError(
      'the no-JIT policy requires a compiled zfa for subprocess tests, but '
      'the AOT build did not produce one:\n$e\n'
      'Fix the build (or the disk/SDK it needs), or set $kZfaAllowJitEnv=1 '
      'to spawn `dart bin/zfa.dart` — degraded environments only.',
    );
  }
}

/// Run `zfa` as a subprocess with an explicit [workingDirectory].
///
/// Because the command executes in a separate process, no process-global
/// `Directory.current` mutation (and no plugin-registry / singleton state)
/// leaks back into the parent test process. This is the hermetic pattern used
/// by the MakeCommand #307 identity-contract group, and it keeps these
/// end-to-end CLI tests from contaminating — or being contaminated by — other
/// test files under parallel `dart test` (issue #506).
///
/// The child is the compiled AOT executable ([zfaExePath]) — `dart
/// bin/zfa.dart` survives only under the explicit `ZFA_ALLOW_JIT=1` escape
/// hatch, shaped by `ZfaExecutable.commandFor` so no site can drift. Both
/// paths are supervised by the same kill-on-timeout guard ([_runSupervised])
/// so a hung child fails fast instead of silently occupying the test until
/// the group timeout is exhausted (issue #531).
Future<ProcessResult> runZfaSource(
  List<String> args, {
  required String workingDirectory,
  Duration? timeout,
}) async {
  assert(zfaSourceBin != null, 'call initZfaSourceBin() in setUpAll');
  final exe = zfaExePath;
  assert(exe != null, 'call initZfaSourceBin() in setUpAll');

  // Default budget: 75s base x ZFA_TEST_TIMEOUT_SCALE (issue #1187). Nullable
  // parameter (instead of a const default) because the scaled budget is
  // computed at isolate start, not a compile-time constant.
  //
  // Issue #1623: the FIRST cold source spawn (the ZFA_ALLOW_JIT=1 shape,
  // where the child pays an 84s-measured cold JIT start before doing any
  // work) spends the dedicated 240s cold budget instead — the flat 75s
  // guard cannot cover it. The decision is pure (resolveChildTimeout) and
  // the spent-once flag is isolate-global, mirroring zfaExePath.
  final sourceSpawn = ZfaExecutable.isDartScript(exe!);
  final coldBudgetAvailable = sourceSpawn && !_zfaColdSourceBudgetSpent;
  final childTimeout = resolveChildTimeout(
    explicit: timeout,
    sourceSpawn: sourceSpawn,
    coldBudgetAvailable: coldBudgetAvailable,
  );
  if (sourceSpawn && timeout == null) _zfaColdSourceBudgetSpent = true;

  // AOT fast path (milliseconds per spawn); the `dart <script>` shape only
  // exists under ZFA_ALLOW_JIT=1 (enforced by commandFor).
  final command = ZfaExecutable.commandFor(exe, args);

  // Child guard MUST be shorter than the enclosing test *group* timeout (see
  // `xray_mock_cli_test.dart:38`). A hanging/over-slow spawn is killed here and
  // fails fast with a clear diagnostic instead of silently consuming the whole
  // group window — which is exactly the `TimeoutException after 0:02:00` the
  // Linux runner hit (#531). 75s is the default: ample headroom for a
  // legitimate cold `dart` source fallback while never exceeding the 2-minute
  // group cap. Callers that drive `build_runner` (e.g. `zfa build`) pass a
  // longer budget, because the first `build.dart` AOT compile + codegen can
  // legitimately exceed 75s under concurrency contention (#531, SC-001).
  // Slow machines raise the default via ZFA_TEST_TIMEOUT_SCALE (#1187) and
  // the feature_flags suite's scaled `Timeout` ceilings grow with it, so the
  // guard stays inside the ceiling at any scale.

  // On Linux a freshly-written AOT binary can refuse to execute with
  // `Text file busy` (ETXTBSY) for a few milliseconds after the write
  // completes, and the AOT path is the one that lands on the CI runner. The
  // atomic rename in `ZfaExecutable.ensureCompiled` removes the
  // half-written-binary window; this retry is the second line of defense for
  // the rare case where the kernel still holds the exec cache. The JIT
  // escape-hatch `dart` path never hits ETXTBSY, so retries only cost a few
  // milliseconds.
  const maxRetries = 3;
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await _runSupervised(
        command,
        timeout: childTimeout,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (e) {
      final busy =
          e.toString().contains('Text file busy') ||
          e.toString().contains('ETXTBSY');
      if (!busy || attempt == maxRetries - 1) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
  // Unreachable: the loop either returns or rethrows.
  throw StateError('runZfaSource retry loop exited without result');
}

/// Start [command] (first element is the executable) in [workingDirectory],
/// capture its stdout/stderr, and supervise it with [timeout]. If the child has
/// not exited when [timeout] elapses, it is killed (SIGKILL) and a
/// [ProcessResult] with exit code `-1` is returned.
///
/// Used for both the `dart compile exe` step and the CLI-under-test spawn.
///
/// Child output is redirected to temp files (via a `sh -c` wrapper) instead of
/// captured through a pipe. The AOT `zfa` executable deadlocks on a *piped*
/// stdout when spawned from `dart test` in some sandboxed environments — it exits
/// cleanly when its stdout is inherited or a plain file. Writing to files avoids
/// the hang while still letting tests assert on the captured output. Plain
/// [Process.run].timeout would only stop awaiting the future and never cancel the
/// child, so we drive the wrapper via [Process.start] and kill it on timeout to
/// avoid leaking processes.
Future<ProcessResult> _runSupervised(
  List<String> command, {
  required Duration timeout,
  required String workingDirectory,
}) async {
  final tmp = await Directory.systemTemp.createTemp('zfa_run_');
  final outPath = p.join(tmp.path, 'out');
  final errPath = p.join(tmp.path, 'err');

  // Quote any arg that is not purely [word/./:/=+/-] so paths/flags survive the
  // shell wrapper; redirect the child's stdout/stderr to the temp files.
  String quote(String arg) {
    if (arg.contains(RegExp(r'''[^\w./:=+\-]'''))) {
      return "'${arg.replaceAll("'", r"'\''")}'";
    }
    return arg;
  }

  final shellCmd = '${command.map(quote).join(' ')} > "$outPath" 2> "$errPath"';

  final process = await Process.start('sh', [
    '-c',
    shellCmd,
  ], workingDirectory: workingDirectory);

  int exitCode;
  String stdout;
  String stderr;
  try {
    exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        // Surface the real cause instead of letting the group timeout swallow
        // it: name the exact `zfa` command that wedged (#531).
        throw TimeoutException(
          'zfa subprocess exceeded its ${timeout.inSeconds}s child timeout: '
          '${command.join(' ')}',
          timeout,
        );
      },
    );
    // Drain any trailing stderr and give the shell a moment to flush the
    // redirected files before reading them back.
    await process.stderr.drain().catchError((_) {});
    stdout = await File(outPath).readAsString();
    stderr = await File(errPath).readAsString();
    return ProcessResult(process.pid, exitCode, stdout, stderr);
  } finally {
    process.kill(ProcessSignal.sigkill);
  }
}

/// Merge the captured stdout + stderr into a single string.
///
/// The in-process `CliRunner.runCapturing` funnels both normal and error
/// output through one `print` zone, so the original tests asserted against a
/// single combined stream. [combinedOutput] reproduces that for the
/// subprocess variant so the assertions can stay unchanged.
String combinedOutput(ProcessResult result) =>
    '${result.stdout}${result.stderr}';
