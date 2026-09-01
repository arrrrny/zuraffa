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

  test('adds all six missing dev_dependencies', () async {
    await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies: {}
''');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    final added = await patcher.ensure(tmpDir.path);
    expect(added.length, 6);
    expect(added.any((e) => e.startsWith('flutter_test')), isTrue);
    expect(added.any((e) => e.startsWith('mocktail')), isTrue);
    expect(added.any((e) => e.startsWith('build_runner')), isTrue);
    expect(added.any((e) => e.startsWith('json_serializable')), isTrue);
    expect(added.any((e) => e.startsWith('coverage')), isTrue);
    expect(added.any((e) => e.startsWith('mutation_test')), isTrue);
    final raw = await File(p.join(tmpDir.path, 'pubspec.yaml')).readAsString();
    final doc = loadYaml(raw) as YamlMap;
    final devDeps = doc['dev_dependencies'] as YamlMap;
    expect(
      devDeps.keys,
      containsAll([
        'flutter_test',
        'mocktail',
        'build_runner',
        'json_serializable',
        'coverage',
        'mutation_test',
      ]),
    );
  });

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
    expect(added.length, 4);
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
    expect(added.length, 6);
    final raw = await File(p.join(tmpDir.path, 'pubspec.yaml')).readAsString();
    expect(raw, contains('dev_dependencies:'));
    expect(raw, contains('flutter_test:'));
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

  // Bug #688: generated TDD tests import `package:test/test.dart`, but the
  // pure-Dart dev_dependencies map was missing the `test` package, so the
  // generated tests were uncompilable out of the box
  // ("Could not find package `test`").
  group('bug #688 — pure Dart projects get package:test', () {
    test(
      'dartDevDependencies includes test ^1.25.0 and ensures it lands',
      () async {
        await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies: {}
''');
        const patcher = PubspecDevDependenciesPatcher(isFlutter: false);
        // The map itself carries the fix.
        expect(
          PubspecDevDependenciesPatcher.dartDevDependencies['test'],
          '^1.25.0',
        );
        final added = await patcher.ensure(tmpDir.path);
        expect(added.any((e) => e.startsWith('test:')), isTrue);
        final raw = await File(
          p.join(tmpDir.path, 'pubspec.yaml'),
        ).readAsString();
        expect(raw, contains('test: ^1.25.0'));
      },
    );

    test(
      'flutterDevDependencies does NOT include test (flutter_test only)',
      () async {
        expect(
          PubspecDevDependenciesPatcher.flutterDevDependencies.containsKey(
            'test',
          ),
          isFalse,
          reason:
              'Flutter projects use flutter_test; adding test would be '
              'redundant and could cause version conflicts',
        );
        expect(
          PubspecDevDependenciesPatcher.flutterDevDependencies.containsKey(
            'flutter_test',
          ),
          isTrue,
        );
      },
    );

    test('dry-run for a Dart project reports test as missing', () async {
      await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies:
  mocktail: ^1.0.0
''');
      const patcher = PubspecDevDependenciesPatcher(isFlutter: false);
      final missing = await patcher.ensure(tmpDir.path, dryRun: true);
      // Dry-run reports package NAMES (unlike ensure()'s rendered entries).
      expect(missing, contains('test'));
      // Dry-run never touched the file: test still absent.
      final raw = await File(
        p.join(tmpDir.path, 'pubspec.yaml'),
      ).readAsString();
      expect(raw.contains('test:'), isFalse);
    });
  });
}
