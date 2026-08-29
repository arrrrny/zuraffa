/// GYM warmup rep #1 — resolve package dependencies (Flutter).
///
/// Run: `dart run .gym/warmup/01-deps.dart`
library;

import 'dart:io';

Future<void> main() async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in cwd=${Directory.current.path}');
    stderr.writeln('Run this rep from the zikzak_inappwebview package root.');
    exit(1);
  }

  // zikzak_inappwebview is a Flutter plugin — use `flutter pub get`
  // if flutter is on PATH, fall back to `dart pub get` otherwise.
  final hasFlutter = (await Process.run('which', ['flutter'])).exitCode == 0;
  final cmd = hasFlutter ? 'flutter' : 'dart';
  final args = hasFlutter ? ['pub', 'get'] : ['pub', 'get'];

  final result = await Process.run(cmd, args);
  if (result.exitCode != 0) {
    stderr.writeln('REP FAIL: 01-deps — `$cmd pub get` exited ${result.exitCode}');
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

  stdout.writeln('REP PASS: 01-deps — dependencies resolved.');
  exit(0);
}
