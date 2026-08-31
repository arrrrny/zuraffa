import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'project_root.dart';

/// Path to `bin/zfa.dart` resolved from the zuraffa project root.
///
/// Resolve once per test file via [initZfaSourceBin] (call it from `setUpAll`).
String? zfaSourceBin;

/// The absolute zuraffa project root, resolved once via [initZfaSourceBin].
///
/// Used as the subprocess `workingDirectory` so the child process never
/// inherits a contested / deleted temp dir as its CWD (the commands target
/// their sandbox via an explicit `--root`, so the child CWD is irrelevant to
/// what gets written). Always exists and is never deleted by a test, so it is
/// a safe, hermetic CWD for the child (issue #506).
late String zfaProjectRoot;

/// Precompiled AOT executable for `bin/zfa.dart`, built once per test file in
/// [initZfaSourceBin].
///
/// Every spawned `dart bin/zfa.dart` process paid the cost of the `dart`
/// front-end + JIT compile of the entire zuraffa package before it could run a
/// single command. The `xray` integration group launches the CLI six times; at
/// ~20s of cold compile per spawn that already exceeds the 2-minute *group*
/// timeout on its own (issue #531). Running a precompiled AOT executable
/// instead drops each spawn to milliseconds, which is what makes the group
/// complete well within budget. `null` when the build is unavailable/failed,
/// in which case [runZfaSource] falls back to `dart bin/zfa.dart`.
String? zfaExePath;

/// Resolve [zfaSourceBin], [zfaProjectRoot], and (best-effort) [zfaExePath].
///
/// Uses [findProjectRoot], which tolerates a contaminated `Directory.current`
/// (see `test/helpers/project_root.dart`): it only rewrites the process CWD
/// when the current directory is already invalid, never while a valid
/// directory is the process CWD. Call this from `setUpAll` so the per-test
/// bodies never touch the process-global working directory.
Future<void> initZfaSourceBin() async {
  final root = await findProjectRoot();
  zfaProjectRoot = root;
  zfaSourceBin = p.join(root, 'bin', 'zfa.dart');
  zfaExePath = await _buildZfaExeIfPossible();
}

/// Build an AOT executable for [zfaSourceBin] under `.dart_tool` (reusing a
/// prior build when no CLI dependency has changed).
///
/// Returns the executable path on success, or `null` if `dart compile exe` is
/// unavailable or fails (e.g. under a constrained environment), so the caller
/// can fall back to running the source. The compile child is supervised with a
/// kill-on-timeout guard so a hung build never leaks into `setUpAll`.
Future<String?> _buildZfaExeIfPossible() async {
  final exeDir = p.join(zfaProjectRoot, '.dart_tool', 'zfa_cli_bin');
  final exePath = p.join(exeDir, 'zfa_exe');
  final exeFile = File(exePath);
  final lockPath = p.join(exeDir, 'build.lock');
  final lockFile = File(lockPath);

  // Reuse a previous build unless the entrypoint or any file under lib/src is
  // newer than the executable (invalidate the cache when CLI deps change).
  if (exeFile.existsSync() && !_isExeStale(exeFile)) {
    return exePath;
  }

  // Serialize the AOT build across parallel test files. Each test file calls
  // `initZfaSourceBin()` in its own `setUpAll`, and `dart test` runs multiple
  // files concurrently — without a lock every file starts its own
  // `dart compile exe` writing to the same `.dart_tool/zfa_cli_bin/zfa_exe`.
  // The losers either exec a half-written binary (Linux ETXTBSY /
  // "Text file busy" — the failure that made `zfa feature enable notes` die on
  // the CI runner, issue #644) or fall back to the slow `dart bin/zfa.dart`
  // path and time out. The lock makes exactly one process compile; everyone
  // else waits for the result and reuses the cached binary.
  RandomAccessFile? lock;
  try {
    lock = await _acquireLock(lockFile);
    // Re-check staleness while holding the lock: another process may have just
    // finished a build while we waited.
    if (exeFile.existsSync() && !_isExeStale(exeFile)) {
      return exePath;
    }

    await Directory(exeDir).create(recursive: true);

    // Build to a temp path and atomically rename into place. On Linux the
    // kernel refuses to exec a file that is currently being written (ETXTBSY /
    // "Text file busy"), and parallel test files each call
    // `_buildZfaExeIfPossible()` in their own `setUpAll`. Writing the final
    // path directly means a concurrent test can start the AOT binary while
    // `dart compile exe` is still appending to it — the exact race that made
    // `zfa feature enable notes` fail on the CI runner with
    // `sh: 1: .../zfa_exe: Text file busy` (issue #644). Compiling to a temp
    // sibling and `renameSync`-ing it makes the final path appear fully-formed
    // or not at all, so no spawn ever lands on a half-written binary.
    final tmpPath = p.join(exeDir, 'zfa_exe.tmp');
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) tmpFile.deleteSync();
    final result = await _runSupervised(
      ['dart', 'compile', 'exe', zfaSourceBin!, '--output', tmpPath],
      timeout: const Duration(seconds: 100),
      workingDirectory: zfaProjectRoot,
    );
    if (result.exitCode == 0 && tmpFile.existsSync()) {
      tmpFile.renameSync(exePath);
      return exePath;
    }
  } on Object {
    // Any failure (compile error, timeout, missing SDK) → source fallback.
  } finally {
    await lock?.close();
    // Drop the lock file so stale locks don't accumulate across test runs.
    if (lockFile.existsSync()) {
      try {
        lockFile.deleteSync();
      } on Object {
        // Best-effort cleanup; never let cleanup failure mask the real result.
      }
    }
  }
  return null;
}

/// Acquire an exclusive advisory lock on [lockFile], retrying with a short
/// backoff until it succeeds.
///
/// Uses `File.open()` + `lockSync()` (POSIX `flock`) so the lock is tied to the
/// file descriptor, not a process — a crashed or killed test process releases
/// it automatically. `dart test` runs multiple test files concurrently, so
/// every caller must contend for the same lock; the retry loop prevents the
/// build from being attempted twice in parallel.
Future<RandomAccessFile> _acquireLock(File lockFile) async {
  final deadline = DateTime.now().add(const Duration(minutes: 5));
  while (true) {
    try {
      final file = await lockFile.open(mode: FileMode.write);
      file.lockSync();
      return file;
    } on Object {
      // `flock` on an already-locked file throws on some platforms; retry
      // rather than failing the whole test file. Some platforms don't
      // support `FileLock` at all, in which case the retry loop still lets
      // the build happen (serially) when possible.
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }
}

/// True when [exeFile] is older than the CLI entrypoint ([zfaSourceBin]) or any
/// file under `lib/src`, meaning the cached AOT executable is stale and must be
/// rebuilt so the integration tests don't run against stale CLI code.
bool _isExeStale(File exeFile) {
  final exeMtime = exeFile.lastModifiedSync();
  if (_isNewer(zfaSourceBin!, exeMtime)) return true;
  final libDir = Directory(p.join(zfaProjectRoot, 'lib', 'src'));
  if (libDir.existsSync()) {
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && _isNewer(entity.path, exeMtime)) return true;
    }
  }
  return false;
}

bool _isNewer(String path, DateTime reference) =>
    File(path).lastModifiedSync().isAfter(reference);

/// Run `zfa` as a subprocess with an explicit [workingDirectory].
///
/// Because the command executes in a separate process, no process-global
/// `Directory.current` mutation (and no plugin-registry / singleton state)
/// leaks back into the parent test process. This is the hermetic pattern used
/// by the MakeCommand #307 identity-contract group, and it keeps these
/// end-to-end CLI tests from contaminating — or being contaminated by — other
/// test files under parallel `dart test` (issue #506).
///
/// Prefers the precompiled AOT executable ([zfaExePath]); falls back to
/// `dart bin/zfa.dart` when it is unavailable. Both paths are supervised by the
/// same kill-on-timeout guard ([_runSupervised]) so a hung child fails fast
/// instead of silently occupying the test until the group timeout is exhausted
/// (issue #531).
Future<ProcessResult> runZfaSource(
  List<String> args, {
  required String workingDirectory,
  Duration timeout = const Duration(seconds: 75),
}) async {
  assert(zfaSourceBin != null, 'call initZfaSourceBin() in setUpAll');

  final command = zfaExePath != null
      ? [zfaExePath!, ...args] // AOT fast path (milliseconds per spawn)
      : ['dart', zfaSourceBin!, ...args]; // source fallback

  // Child guard MUST be shorter than the enclosing test *group* timeout (see
  // `xray_mock_cli_test.dart:38`). A hanging/over-slow spawn is killed here and
  // fails fast with a clear diagnostic instead of silently consuming the whole
  // group window — which is exactly the `TimeoutException after 0:02:00` the
  // Linux runner hit (#531). 75s is the default: ample headroom for a
  // legitimate cold `dart` source fallback while never exceeding the 2-minute
  // group cap. Callers that drive `build_runner` (e.g. `zfa build`) pass a
  // longer budget, because the first `build.dart` AOT compile + codegen can
  // legitimately exceed 75s under concurrency contention (#531, SC-001).

  // On Linux a freshly-written AOT binary can refuse to execute with
  // `Text file busy` (ETXTBSY) for a few milliseconds after the write
  // completes, and the AOT path is the one that lands on the CI runner. The
  // atomic rename in `_buildZfaExeIfPossible` removes the half-written-binary
  // window; this retry is the second line of defense for the rare case where
  // the kernel still holds the exec cache. The fallback `dart` path never
  // hits ETXTBSY, so retries only cost a few milliseconds.
  const maxRetries = 3;
  for (var attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await _runSupervised(
        command,
        timeout: timeout,
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
