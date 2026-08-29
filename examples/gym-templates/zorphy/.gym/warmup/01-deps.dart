/// GYM warmup rep #1 — resolve package dependencies.
///
/// Run: `dart run .gym/warmup/01-deps.dart`
///
/// A mis-fire is a DROP CARD — see github.com/arrrrny/drop-card.
library;

import 'dart:io';

Future<void> main() async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in cwd=${Directory.current.path}');
    stderr.writeln('Run this rep from the zorphy package root.');
    exit(1);
  }

  final result = await Process.run('dart', ['pub', 'get']);
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 01-deps — `dart pub get` exited ${result.exitCode}');
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    exit(result.exitCode);
  }

  final pkgConfig = File('.dart_tool/package_config.json');
  if (!pkgConfig.existsSync()) {
    stderr.writeln(
      'REP FAIL: 01-deps — pub get exited 0 but .dart_tool/package_config.json '
      'is missing. Mis-fire — drop a card.',
    );
    exit(1);
  }

  // The package_config.json must reference zorphy itself.
  final configText = pkgConfig.readAsStringSync();
  if (!configText.contains('"name":"zorphy"') &&
      !configText.contains('"name": "zorphy"')) {
    stderr.writeln(
      'REP FAIL: 01-deps — package_config.json does not reference the '
      '`zorphy` root package. Mis-fire — drop a card.',
    );
    exit(1);
  }

  stdout.writeln('REP PASS: 01-deps — dependencies resolved.');
  exit(0);
}
