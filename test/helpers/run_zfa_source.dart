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

/// Resolve [zfaSourceBin] and [zfaProjectRoot] from the zuraffa project root.
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
}

/// Run `zfa` from SOURCE as a subprocess with an explicit [workingDirectory].
///
/// Because the command executes in a separate process, no process-global
/// `Directory.current` mutation (and no plugin-registry / singleton state)
/// leaks back into the parent test process. This is the hermetic pattern used
/// by the MakeCommand #307 identity-contract group, and it keeps these
/// end-to-end CLI tests from contaminating — or being contaminated by — other
/// test files under parallel `dart test` (issue #506).
Future<ProcessResult> runZfaSource(
  List<String> args, {
  required String workingDirectory,
}) {
  assert(zfaSourceBin != null, 'call initZfaSourceBin() in setUpAll');
  return Process.run(
    'dart',
    [zfaSourceBin!, ...args],
    workingDirectory: workingDirectory,
  );
}

/// Merge the captured stdout + stderr into a single string.
///
/// The in-process `CliRunner.runCapturing` funnels both normal and error
/// output through one `print` zone, so the original tests asserted against a
/// single combined stream. [combinedOutput] reproduces that for the
/// subprocess variant so the assertions can stay unchanged.
String combinedOutput(ProcessResult result) =>
    '${result.stdout}${result.stderr}';
