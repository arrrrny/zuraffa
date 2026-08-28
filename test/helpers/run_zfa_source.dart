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
/// prior build when it is newer than the source).
///
/// Returns the executable path on success, or `null` if `dart compile exe` is
/// unavailable or fails (e.g. under a constrained environment), so the caller
/// can fall back to running the source. The build is bounded and never leaks
/// a hang into `setUpAll`.
Future<String?> _buildZfaExeIfPossible() async {
  final exeDir = p.join(zfaProjectRoot, '.dart_tool', 'zfa_cli_bin');
  final exePath = p.join(exeDir, 'zfa_exe');
  final exeFile = File(exePath);

  // Reuse a previous build unless the source has changed since.
  if (exeFile.existsSync()) {
    try {
      final sourceMtime = File(zfaSourceBin!).lastModifiedSync();
      final exeMtime = exeFile.lastModifiedSync();
      if (!sourceMtime.isAfter(exeMtime)) return exePath;
    } on Object {
      // Fall through and rebuild.
    }
  }

  try {
    await Directory(exeDir).create(recursive: true);
    final compile = await Process.run(
      'dart',
      ['compile', 'exe', zfaSourceBin!, '--output', exePath],
      workingDirectory: zfaProjectRoot,
    ).timeout(const Duration(seconds: 100));
    if (compile.exitCode == 0 && exeFile.existsSync()) {
      return exePath;
    }
  } on Object {
    // Any failure (compile error, timeout, missing SDK) → source fallback.
  }
  return null;
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
/// Prefers the precompiled AOT executable ([zfaExePath]); falls back to
/// `dart bin/zfa.dart` when it is unavailable. The fallback spawn is wrapped in
/// a generous 5-minute guard that kills a hung child (this SDK's [Process.run]
/// has no `timeout` parameter, so the guard is implemented with [Process.start]
/// + [Process.kill]) so a genuinely stuck spawn fails fast instead of silently
/// occupying the test until the group timeout is exhausted (issue #531).
Future<ProcessResult> runZfaSource(
  List<String> args, {
  required String workingDirectory,
}) async {
  assert(zfaSourceBin != null, 'call initZfaSourceBin() in setUpAll');

  final exe = zfaExePath;
  if (exe != null) {
    // Fast path: the precompiled executable starts in milliseconds, so a plain
    // [Process.run] is sufficient and avoids any stream/zone wrapping.
    return Process.run(
      exe,
      args,
      workingDirectory: workingDirectory,
    );
  }

  // Fallback path: run the source via `dart`. Guarded so a hang cannot outlive
  // the test budget.
  final process = await Process.start(
    'dart',
    [zfaSourceBin!, ...args],
    workingDirectory: workingDirectory,
  );
  final stdoutBytes = <int>[];
  final stderrBytes = <int>[];
  final outSub = process.stdout.listen(stdoutBytes.addAll);
  final errSub = process.stderr.listen(stderrBytes.addAll);
  try {
    final exitCode = await process.exitCode.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await Future.wait([outSub.asFuture(), errSub.asFuture()]);
    return ProcessResult(
      process.pid,
      exitCode,
      systemEncoding.decode(stdoutBytes),
      systemEncoding.decode(stderrBytes),
    );
  } finally {
    await outSub.cancel();
    await errSub.cancel();
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
