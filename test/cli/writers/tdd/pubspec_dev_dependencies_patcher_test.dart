@Tags(['slow'])
// Tests for the PubspecDevDependenciesPatcher (spec 041-tdd-setup-plugin,
// U16-U18).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('pubspec_patcher_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> writePubspec(String content) async {
    final file = File(p.join(tmpDir.path, 'pubspec.yaml'));
    await file.writeAsString(content);
  }

  test(
    'adds all seven missing dev_dependencies (bug #716 added `test`)',
    () async {
      await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies: {}
''');
      final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
      final added = await patcher.ensure(tmpDir.path);
      expect(added.length, 7);
      expect(added.any((e) => e.startsWith('flutter_test')), isTrue);
      expect(added.any((e) => e.startsWith('test')), isTrue);
      expect(added.any((e) => e.startsWith('mocktail')), isTrue);
      expect(added.any((e) => e.startsWith('build_runner')), isTrue);
      expect(added.any((e) => e.startsWith('json_serializable')), isTrue);
      expect(added.any((e) => e.startsWith('coverage')), isTrue);
      expect(added.any((e) => e.startsWith('mutation_test')), isTrue);
      final raw = await File(
        p.join(tmpDir.path, 'pubspec.yaml'),
      ).readAsString();
      final doc = loadYaml(raw) as YamlMap;
      final devDeps = doc['dev_dependencies'] as YamlMap;
      expect(
        devDeps.keys,
        containsAll([
          'flutter_test',
          'test',
          'mocktail',
          'build_runner',
          'json_serializable',
          'coverage',
          'mutation_test',
        ]),
      );
    },
  );

  test('does not duplicate existing entries', () async {
    await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
''');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    final added = await patcher.ensure(tmpDir.path);
    expect(added.length, 5);
    expect(added.any((e) => e.startsWith('flutter_test')), isFalse);
    expect(added.any((e) => e.startsWith('mocktail')), isFalse);
    final raw = await File(p.join(tmpDir.path, 'pubspec.yaml')).readAsString();
    final flutterTestCount = RegExp(
      r'^\s*flutter_test:',
      multiLine: true,
    ).allMatches(raw).length;
    expect(
      flutterTestCount,
      1,
      reason: 'flutter_test should appear exactly once',
    );
  });

  test('misfire-stop on parse failure (no partial write)', () async {
    final file = File(p.join(tmpDir.path, 'pubspec.yaml'));
    await file.writeAsString('name: myapp\n  bad: : :\n   bad indentation');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    expect(() => patcher.ensure(tmpDir.path), throwsA(isA<FormatException>()));
    final after = await file.readAsString();
    expect(after, contains('bad: : :'));
  });

  test('creates dev_dependencies block when missing', () async {
    await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}
''');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    final added = await patcher.ensure(tmpDir.path);
    expect(added.length, 7);
    final raw = await File(p.join(tmpDir.path, 'pubspec.yaml')).readAsString();
    expect(raw, contains('dev_dependencies:'));
    expect(raw, contains('flutter_test:'));
    expect(raw, contains('test:'));
  });

  test('rejects inline non-empty dev_dependencies mappings', () async {
    await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0
dependencies: {}
dev_dependencies: {lints: ^5.0.0}
''');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    expect(() => patcher.ensure(tmpDir.path), throwsA(isA<UnsupportedError>()));
  });

  // Bug #688: `zfa tdd gen` generates tests importing
  // `package:test/test.dart`, but the `test` package was missing from the
  // pure-Dart dev_dependencies set — generated tests were uncompilable out
  // of the box. These tests pin the Dart-mode contract.
  //
  // Bug #716 amends the Flutter side: `flutter_test` does NOT provide
  // `package:test/test.dart` (it only wraps test_api/matcher), so the
  // Flutter template must also carry `test` — otherwise fresh Flutter
  // projects bootstrapped by `zfa setup` cannot compile their generated
  // tests either.
  group(
    'bug #688/#716 — both Dart and Flutter templates include the test package',
    () {
      test('dartDevDependencies includes test ^1.25.0', () {
        expect(
          PubspecDevDependenciesPatcher.dartDevDependencies['test'],
          '^1.25.0',
        );
      });

      test(
        'flutterDevDependencies includes test ^1.0.0 alongside flutter_test '
        '(bug #716: flutter_test does NOT provide package:test/test.dart)',
        () {
          expect(
            PubspecDevDependenciesPatcher.flutterDevDependencies['test'],
            '^1.0.0',
          );
          expect(
            PubspecDevDependenciesPatcher
                .flutterDevDependencies['flutter_test'],
            'sdk: flutter',
          );
        },
      );

      test(
        'dart-mode ensure adds test (and no flutter_test) to a Dart project',
        () async {
          await writePubspec('''
name: pure_dart_app
environment:
  sdk: ^3.11.0

dev_dependencies:
  lints: ^6.0.0
''');
          final patcher = const PubspecDevDependenciesPatcher(isFlutter: false);
          final added = await patcher.ensure(tmpDir.path);
          final raw = await File(
            p.join(tmpDir.path, 'pubspec.yaml'),
          ).readAsString();
          final doc = loadYaml(raw) as YamlMap;
          final devDeps = doc['dev_dependencies'] as YamlMap;
          expect(devDeps['test'], '^1.25.0');
          expect(
            devDeps.containsKey('flutter_test'),
            isFalse,
            reason:
                'a pure Dart project must not receive the flutter_test SDK dep',
          );
          // Existing entries are preserved, not duplicated.
          expect(added.any((e) => e.startsWith('lints')), isFalse);
          expect(devDeps['lints'], '^6.0.0');
        },
      );

      test(
        'dart-mode ensure does not duplicate an existing test entry',
        () async {
          await writePubspec('''
name: pure_dart_app
environment:
  sdk: ^3.11.0

dev_dependencies:
  test: ^1.25.0
''');
          final patcher = const PubspecDevDependenciesPatcher(isFlutter: false);
          final added = await patcher.ensure(tmpDir.path);
          expect(added.any((e) => e.startsWith('test')), isFalse);
          final raw = await File(
            p.join(tmpDir.path, 'pubspec.yaml'),
          ).readAsString();
          final testCount = RegExp(
            r'^\s*test:',
            multiLine: true,
          ).allMatches(raw).length;
          expect(testCount, 1, reason: 'test should appear exactly once');
        },
      );
    },
  );
}
