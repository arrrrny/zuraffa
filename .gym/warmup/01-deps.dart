/// GYM warmup rep #1 — resolve package dependencies.
///
/// A warmup rep proves the operator can drive the package at all. This one
/// resolves the zuraffa package's own dependencies via `dart pub get` and
/// asserts the produced `.dart_tool/package_config.json` is on disk.
///
/// Run: `dart run .gym/warmup/01-deps.dart`
///
/// A mis-fire (unexpected outcome, not a clean failure) is a DROP CARD —
/// see github.com/arrrrny/drop-card.
library;

import 'dart:io';

/// Entry point for warmup rep #1.
Future<void> main() async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in cwd=${Directory.current.path}');
    stderr.writeln('Run this rep from the zuraffa package root.');
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
      'is missing. Mis-fire — drop a card: '
      'github.com/arrrrny/drop-card',
    );
    exit(1);
  }

  // The package_config.json must reference the zuraffa package itself
  // (proves the package was resolved as a self-importable root).
  final configText = pkgConfig.readAsStringSync();
  if (!configText.contains('"name":"zuraffa"') &&
      !configText.contains('"name": "zuraffa"')) {
    stderr.writeln(
      'REP FAIL: 01-deps — package_config.json does not reference the '
      '`zuraffa` root package. Mis-fire — drop a card.',
    );
    exit(1);
  }

  stdout.writeln('REP OK: 01-deps — dependencies resolved.');
}
