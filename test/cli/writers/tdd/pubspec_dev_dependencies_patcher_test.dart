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

  test('adds all six missing dev_dependencies '
      '(bug #716 added `test`; bug #755 dropped unused `mocktail`)', () async {
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
    expect(added.any((e) => e.startsWith('test')), isTrue);
    expect(
      added.any((e) => e.startsWith('mocktail')),
      isFalse,
      reason: 'bug #755: mocktail is no longer written into generated pubspecs',
    );
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
        'test',
        'build_runner',
        'json_serializable',
        'coverage',
        'mutation_test',
      ]),
    );
    expect(devDeps.containsKey('mocktail'), isFalse);
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
  build_runner: ^2.4.0
''');
    final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
    final added = await patcher.ensure(tmpDir.path);
    // flutter_test and build_runner are pre-declared; the patcher should
    // add the remaining 4 (test, json_serializable, coverage, mutation_test).
    expect(added.length, 4);
    expect(added.any((e) => e.startsWith('flutter_test')), isFalse);
    expect(added.any((e) => e.startsWith('build_runner')), isFalse);
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
    // bug #755 dropped mocktail from the flutter map: 7 -> 6.
    expect(added.length, 6);
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

  // Bug #755: `zfa tdd init` pinned `mutation_test: ^1.0.0` but the
  // toolchain's MutationVerifier (lib/src/plugins/tdd/services/
  // mutation_verifier.dart:235,255) parses v1.8.0+ reports. The
  // generated baseline was internally inconsistent out of the box.
  //
  // Remediation: bump both maps to `^1.8.0`, update `coverage` to the
  // current latest (`^1.15.1`), and drop the unused `mocktail` dev
  // dependency — the generated test templates use zuraffa's native
  // mocks (`lib/src/mock/mock.dart`, `test_builder_entity.dart:6`)
  // and never import `package:mocktail`.
  group('bug #755 — pins match MutationVerifier v1.8.0+ format', () {
    test(
      'flutterDevDependencies pins mutation_test at ^1.8.0 (matches verifier)',
      () {
        expect(
          PubspecDevDependenciesPatcher.flutterDevDependencies['mutation_test'],
          '^1.8.0',
          reason:
              'MutationVerifier parses v1.8.0+ reports; the generated pin '
              'must agree so freshly initialized projects are not internally '
              'inconsistent out of the box.',
        );
      },
    );

    test(
      'dartDevDependencies pins mutation_test at ^1.8.0 (matches verifier)',
      () {
        expect(
          PubspecDevDependenciesPatcher.dartDevDependencies['mutation_test'],
          '^1.8.0',
        );
      },
    );

    test(
      'flutterDevDependencies pins coverage at ^1.15.1 (current latest)',
      () {
        expect(
          PubspecDevDependenciesPatcher.flutterDevDependencies['coverage'],
          '^1.15.1',
          reason:
              'Bug #755 asks for the latest coverage pin at merge time. '
              'pub.dev reports 1.15.1 as the current latest stable release.',
        );
      },
    );

    test('dartDevDependencies pins coverage at ^1.15.1 (current latest)', () {
      expect(
        PubspecDevDependenciesPatcher.dartDevDependencies['coverage'],
        '^1.15.1',
      );
    });

    test('flutterDevDependencies does NOT include mocktail '
        '(unused by generated test templates)', () {
      expect(
        PubspecDevDependenciesPatcher.flutterDevDependencies.containsKey(
          'mocktail',
        ),
        isFalse,
        reason:
            'Generated tests use zuraffa native mocks '
            '(lib/src/mock/mock.dart, test_builder_entity.dart:6); '
            'mocktail was an unused dev dep that just bloats the '
            'generated baseline.',
      );
    });

    test('dartDevDependencies does NOT include mocktail '
        '(unused by generated test templates)', () {
      expect(
        PubspecDevDependenciesPatcher.dartDevDependencies.containsKey(
          'mocktail',
        ),
        isFalse,
      );
    });

    test(
      'flutter-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml',
      () async {
        await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dependencies: {}

dev_dependencies: {}
''');
        final patcher = const PubspecDevDependenciesPatcher(isFlutter: true);
        await patcher.ensure(tmpDir.path);
        final raw = await File(
          p.join(tmpDir.path, 'pubspec.yaml'),
        ).readAsString();
        final doc = loadYaml(raw) as YamlMap;
        final devDeps = doc['dev_dependencies'] as YamlMap;
        expect(devDeps['mutation_test'], '^1.8.0');
        expect(devDeps['coverage'], '^1.15.1');
        expect(
          devDeps.containsKey('mocktail'),
          isFalse,
          reason: 'mocktail must not be written into generated pubspecs',
        );
      },
    );

    test(
      'dart-mode ensure writes mutation_test: ^1.8.0 into pubspec.yaml',
      () async {
        await writePubspec('''
name: myapp
environment:
  sdk: ^3.11.0

dev_dependencies: {}
''');
        final patcher = const PubspecDevDependenciesPatcher(isFlutter: false);
        await patcher.ensure(tmpDir.path);
        final raw = await File(
          p.join(tmpDir.path, 'pubspec.yaml'),
        ).readAsString();
        final doc = loadYaml(raw) as YamlMap;
        final devDeps = doc['dev_dependencies'] as YamlMap;
        expect(devDeps['mutation_test'], '^1.8.0');
        expect(devDeps['coverage'], '^1.15.1');
        expect(devDeps.containsKey('mocktail'), isFalse);
      },
    );
  });
}
