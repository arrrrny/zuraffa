// Issue #1370 — `zfa tdd init` wrote `test: ^1.0.0` into Flutter
// consumers where the constraint CANNOT resolve: with graphql
// ^5.2.3 → web_socket_channel ^3.0.1 in the graph, no published `test`
// version is compatible with flutter_test's test_api/matcher pins —
// exactly the conflict class zuraffa itself documented and fixed for its
// own package in issue #1189. The result: `flutter pub get` broke in
// every project init "fixed".
//
// Resolution (spec 1370-flutter-consumer-test-baseline): on Flutter
// projects the baseline EXCLUDES plain `test` — the gen-side import
// policy (issue #1351) emits `package:flutter_test/flutter_test.dart`
// for unit/acceptance/ffi templates on Flutter hosts, and flutter_test
// re-exports the same group/test/expect API. Pure-Dart projects keep
// `test: ^1.25.0` (the dart lane still needs the runner package).
//
// Behaviors:
//   B1 — Flutter consumer: the patcher prescribes NO plain `test`.
//   B2 — pure-Dart project: `test: ^1.25.0` is still prescribed (guard).
//   B3 — the shipped example/ Flutter consumer declares no plain `test`
//        (the #1369 pin superseded by this spec).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';

const flutterPubspec = '''
name: fixture_flutter
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''';

const dartPubspec = '''
name: fixture_pure
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('tdd_1370_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('B1: a Flutter consumer is prescribed NO plain test package',
      () async {
    final project = Directory(p.join(tmpDir.path, 'flutter_app'))
      ..createSync(recursive: true);
    await File(p.join(project.path, 'pubspec.yaml'))
        .writeAsString(flutterPubspec);

    final added = await const PubspecDevDependenciesPatcher(
      isFlutter: true,
    ).ensure(project.path);

    expect(
      added.where((e) => e.startsWith('test:')),
      isEmpty,
      reason: 'the plain test package is unresolvable in the Flutter '
          'graph (#1189/#1370) — flutter_test re-exports the API',
    );
    expect(added.any((e) => e.startsWith('coverage')), isTrue);
    expect(added.any((e) => e.startsWith('mutation_test')), isTrue);
    expect(
      loadYaml(
        await File(p.join(project.path, 'pubspec.yaml')).readAsString(),
      )['dev_dependencies'],
      isNot(contains('test')),
    );
  });

  test('B2: a pure-Dart project still gets test ^1.25.0 (guard)', () async {
    final project = Directory(p.join(tmpDir.path, 'pure_dart'))
      ..createSync(recursive: true);
    await File(p.join(project.path, 'pubspec.yaml'))
        .writeAsString(dartPubspec);

    final added = await const PubspecDevDependenciesPatcher(
      isFlutter: false,
    ).ensure(project.path);

    expect(added.where((e) => e.startsWith('test:')), isEmpty,
        reason: 'test is already declared in the pure-Dart fixture');
    final doc = loadYaml(
      await File(p.join(project.path, 'pubspec.yaml')).readAsString(),
    ) as YamlMap;
    final devDeps = doc['dev_dependencies'] as YamlMap;
    expect(devDeps['test'], '^1.25.0');
  });

  test('B3: the shipped example/ Flutter consumer declares no plain test',
      () {
    final doc = loadYaml(
      File('example/pubspec.yaml').readAsStringSync(),
    ) as YamlMap;
    final devDeps = doc['dev_dependencies'] as YamlMap;

    expect(
      devDeps.keys,
      isNot(contains('test')),
      reason: 'the #1369 pin is superseded: the constraint is '
          'unresolvable in this graph (issue #1370)',
    );
    expect(devDeps.keys, containsAll(['flutter_test', 'coverage', 'mutation_test']));
  });
}
