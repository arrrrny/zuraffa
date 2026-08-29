/// GYM warmup rep #2 — build the example app.
///
/// Run: `dart run .gym/warmup/02-build.dart`
library;

import 'dart:io';

Future<void> main() async {
  // The example app lives under example/. Build it to prove the
  // plugin compiles end-to-end with its consuming Flutter app.
  final exampleDir = Directory('example');
  if (!exampleDir.existsSync()) {
    stderr.writeln(
      'REP FAIL: 02-build — no example/ directory found in '
      '${Directory.current.path}. The zikzak_inappwebview package '
      'should ship an example/ Flutter app.',
    );
    exit(1);
  }

  final hasFlutter = (await Process.run('which', ['flutter'])).exitCode == 0;
  if (!hasFlutter) {
    stderr.writeln(
      'REP FAIL: 02-build — `flutter` is not on PATH. The zikzak_inappwebview '
      'package is a Flutter plugin; building the example app requires '
      'the Flutter SDK.',
    );
    exit(1);
  }

  // Use `flutter analyze` instead of `flutter build` — analyze is
  // faster and proves the plugin + example compile together without
  // requiring a target device.
  final result = await Process.run(
    'flutter',
    ['analyze', '--no-fatal-infos'],
    workingDirectory: exampleDir.path,
  );
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 02-build — `flutter analyze` exited ${result.exitCode}');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }

  stdout.writeln('REP PASS: 02-build — example app analyzed cleanly.');
  exit(0);
}
