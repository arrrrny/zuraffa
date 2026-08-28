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

  // Reuse a previous build unless the entrypoint or any file under lib/src is
  // newer than the executable (invalidate the cache when CLI deps change).
  if (exeFile.existsSync() && !_isExeStale(exeFile)) {
    return exePath;
  }

  try {
    await Directory(exeDir).create(recursive: true);
    final result = await _runSupervised(
      ['dart', 'compile', 'exe', zfaSourceBin!, '--output', exePath],
      timeout: const Duration(seconds: 100),
      workingDirectory: zfaProjectRoot,
    );
    if (result.exitCode == 0 && exeFile.existsSync()) {
      return exePath;
    }
  } on Object {
    // Any failure (compile error, timeout, missing SDK) → source fallback.
  }
  return null;
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
}) async {
  assert(zfaSourceBin != null, 'call initZfaSourceBin() in setUpAll');

  final command = zfaExePath != null
      ? [zfaExePath!, ...args] // AOT fast path (milliseconds per spawn)
      : ['dart', zfaSourceBin!, ...args]; // source fallback

  // Generous 5-minute guard so a genuinely stuck spawn fails fast.
  return _runSupervised(
    command,
    timeout: const Duration(minutes: 5),
    workingDirectory: workingDirectory,
  );
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
        return -1;
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
