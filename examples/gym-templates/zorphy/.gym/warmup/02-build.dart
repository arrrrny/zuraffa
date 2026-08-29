/// GYM warmup rep #2 — build + analyze the package.
///
/// Run: `dart run .gym/warmup/02-build.dart`
library;

import 'dart:io';

Future<void> main() async {
  final result = await Process.run('dart', ['analyze', '--fatal-infos']);
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 02-build — `dart analyze` exited ${result.exitCode}');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }

  // The analyze output should not contain any errors.
  final stdoutText = result.stdout.toString();
  if (stdoutText.contains('error -')) {
    stderr.writeln(
      'REP FAIL: 02-build — `dart analyze` reported errors. Mis-fire — '
      'drop a card.',
    );
    stderr.writeln(stdoutText);
    exit(1);
  }

  stdout.writeln('REP PASS: 02-build — package analyzed cleanly.');
  exit(0);
}
