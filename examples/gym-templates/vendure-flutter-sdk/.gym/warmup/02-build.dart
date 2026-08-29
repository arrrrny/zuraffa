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

  stdout.writeln('REP PASS: 02-build — package analyzed cleanly.');
  exit(0);
}
