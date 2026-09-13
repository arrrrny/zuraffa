// SPEC 1530 — the make pubsync post-pass ENSURES `zuraffa` when the
// generated files import `package:zuraffa/...` (FR-007).
//
// The dogfood failure: `zfa make` wrote datasource files importing
// `package:zuraffa/zuraffa.dart` into a target whose pubspec did not
// declare the core package; the #1265 auto-add heals that gap only when
// a network `pub add` can run. The ensure is the offline-safe textual
// declaration riding the same post-pass — the completion output names
// it, and a re-run leaves the pubspec with exactly one declaration.
library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import '../helpers/project_root.dart';

void main() {
  late Directory workspace;
  late String projectRoot;
  late String zfaBin;
  late bool useCompiledBinary;

  setUpAll(() async {
    final homeDir = Platform.environment['HOME'] ?? '';
    final compiledBin = path.join(homeDir, '.local', 'bin', 'zfa');
    final compiledExists = File(compiledBin).existsSync();

    if (compiledExists) {
      zfaBin = compiledBin;
      useCompiledBinary = true;
    } else {
      final root = await findProjectRoot();
      zfaBin = path.join(root, 'bin', 'zfa.dart');
      useCompiledBinary = false;
    }
  });

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_1530_ensure_');
    projectRoot = workspace.path;
    final outputDir = path.join(projectRoot, 'lib', 'src');
    await Directory(
      path.join(outputDir, 'domain', 'entities', 'product'),
    ).create(recursive: true);
    await File(
      path.join(outputDir, 'domain', 'entities', 'product', 'product.dart'),
    ).writeAsString('''
import 'package:zorphy/zorphy.dart';

@Zorphy()
abstract class \$Product {
  String get id;
  String get title;
}
''');
    await File(
      path.join(projectRoot, 'pubspec.yaml'),
    ).writeAsString('''
name: zuraffa_1530_ensure_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: ^2.3.0
  json_annotation: ^4.12.0
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<(String, int)> runMake(List<String> args) async {
    final process = useCompiledBinary
        ? await Process.start(
            zfaBin,
            args,
            workingDirectory: projectRoot,
          )
        : await Process.start(
            'dart',
            [zfaBin, ...args],
            workingDirectory: projectRoot,
          );
    final stdout = process.stdout.transform(systemEncoding.decoder).join();
    final stderr = process.stderr.transform(systemEncoding.decoder).join();
    final code = await process.exitCode;
    return ('${await stdout}\n${await stderr}', code);
  }

  test('A-1530-5-e2e: a make run whose files import package:zuraffa '
      'declares it in the target pubspec and names the ensure', () async {
    final (output, code) = await runMake([
      'make',
      'Product',
      'datasource',
      '--with',
      'mock',
    ]);

    expect(code, 0, reason: 'out:\n$output');
    final pubspec = File(
      path.join(projectRoot, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(
      pubspec,
      contains('zuraffa: ^6.0.0'),
      reason:
          '#1530: the ensure must declare the core package textually '
          '(offline-safe) — pubspec:\n$pubspec',
    );
    expect(
      output,
      contains('Ensured zuraffa'),
      reason: 'the completion receipt must name the ensured declaration:\n'
          '$output',
    );
  });

  test('A-1530-6-e2e: a re-run is idempotent — exactly one declaration',
      () async {
    await runMake(['make', 'Product', 'datasource', '--with', 'mock']);
    final firstPass = File(
      path.join(projectRoot, 'pubspec.yaml'),
    ).readAsStringSync();

    final (output, code) = await runMake([
      'make',
      'Product',
      'datasource',
      '--with',
      'mock',
      '--force',
    ]);

    expect(code, 0, reason: 'out:\n$output');
    final secondPass = File(
      path.join(projectRoot, 'pubspec.yaml'),
    ).readAsStringSync();
    expect(
      'zuraffa:'.allMatches(secondPass).length,
      1,
      reason: 'idempotence: exactly one zuraffa declaration may exist\n'
          'first pass:\n$firstPass\nsecond pass:\n$secondPass',
    );
  });
}
