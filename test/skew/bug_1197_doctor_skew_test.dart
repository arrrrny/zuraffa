import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/doctor_checks.dart';
import 'package:zuraffa/src/skew/skew_contract.dart';
import 'package:zuraffa/src/version.dart';

/// Issue #1197: `zfa doctor` must REPORT skew: the triangle of
/// (a) the target pubspec's zuraffa pin, (b) the installed core the
/// package config resolves to, and (c) the running generator version
/// — and enforce the floors stamped into generation receipts
/// (`min_core_version`), so a stale/downgraded core is diagnosed
/// before generated slices die on it. A core from another major is
/// the hard case: it carries none of the emitted API, so it fails
/// where the rest of the triangle only warns.
void main() {
  late Directory temp;
  late Directory coreDir;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('zfa1197_doctor_');
    coreDir = await Directory.systemTemp.createTemp('zfa1197_doctor_core_');
    Directory(path.join(coreDir.path, 'lib')).createSync(recursive: true);
    File(
      path.join(coreDir.path, 'lib', 'zuraffa.dart'),
    ).writeAsStringSync('export "src/core/result.dart";\n');
    File(
      path.join(coreDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: zuraffa\nversion: $generatorMajor.0.0\n');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
    await coreDir.delete(recursive: true);
  });

  void writePubspec({required String pin}) {
    File(path.join(temp.path, 'pubspec.yaml')).writeAsStringSync('''
name: doctor_skew_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa: $pin
''');
  }

  void writePackageConfig({required String coreVersion}) {
    File(
      path.join(coreDir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: zuraffa\nversion: $coreVersion\n');
    Directory(path.join(temp.path, '.dart_tool')).createSync(recursive: true);
    File(
      path.join(temp.path, '.dart_tool', 'package_config.json'),
    ).writeAsStringSync(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'zuraffa',
            'rootUri': coreDir.uri.toString(),
            'packageUri': 'lib/',
            'languageVersion': '3.11',
          },
        ],
      }),
    );
  }

  void writeReceipt({
    required String minCoreVersion,
    required String generatedAgainstCore,
  }) {
    final receipts = Directory(path.join(temp.path, '.zfa', 'receipts'))
      ..createSync(recursive: true);
    File(path.join(receipts.path, 'make.json')).writeAsStringSync(
      jsonEncode({
        'schema': 'proof.v1',
        'command': 'make',
        'target': 'Todo',
        'generator_version': version,
        'min_core_version': minCoreVersion,
        'generated_against_core': generatedAgainstCore,
      }),
    );
  }

  Future<DoctorCheckResult> runCheck() async =>
      DoctorChecksRunner(projectDir: temp.path)
          .runAll(fix: false)
          .then((results) => results.firstWhere((r) => r.id == 'runtime-skew'));

  test('is part of the named check set (#793 registry)', () async {
    writePubspec(pin: '^$version');
    final ids = (await DoctorChecksRunner(
      projectDir: temp.path,
    ).runAll(fix: false)).map((r) => r.id).toList();
    expect(ids, contains('runtime-skew'));
  });

  test('skipped when there is no pubspec (not a Dart project)', () async {
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.skipped);
  });

  test('pass when pin, installed core and generator agree', () async {
    writePubspec(pin: '^$version');
    writePackageConfig(coreVersion: version);
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.pass);
    expect(result.detail, contains('v$version'));
  });

  test('fail when the installed core is from another major', () async {
    final other = '${generatorMajor - 1}.99.99';
    writePubspec(pin: '^$other');
    writePackageConfig(coreVersion: other);
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.fail);
    expect(result.detail, contains('v$other'));
    expect(result.detail, contains('not a $generatorMajor.x core'));
    expect(
      result.suggestedFix,
      allOf(contains('zuraffa: $consumerCoreConstraint'), contains('yaml')),
    );
  });

  test(
    'a cross-major core fails even when every receipt floor is satisfied',
    () async {
      final other = '${generatorMajor - 1}.99.99';
      writePubspec(pin: '^$other');
      writePackageConfig(coreVersion: other);
      // Receipts stamped by the previous major's generator are all
      // satisfied by the previous major's core; the skew is the
      // generator, and only the major check can see it.
      writeReceipt(minCoreVersion: other, generatedAgainstCore: other);
      final result = await runCheck();
      expect(result.status, DoctorCheckStatus.fail);
      expect(result.detail, contains('not a $generatorMajor.x core'));
    },
  );

  test('warn when the pubspec pin major is behind the CLI major', () async {
    writePubspec(pin: '^${generatorMajor - 2}.0.0');
    writePackageConfig(coreVersion: version);
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.warn);
    expect(result.detail, contains('behind'));
    expect(result.suggestedFix, 'dart pub upgrade zuraffa');
  });

  test('warn when the installed core is older than the pin', () async {
    writePubspec(pin: '^$generatorMajor.1.0');
    writePackageConfig(coreVersion: '$generatorMajor.0.0');
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.warn);
    expect(result.detail, contains('older than the pin'));
  });

  test(
    'fail when a receipt floor (min_core_version) exceeds the installed core',
    () async {
      writePubspec(pin: '^$generatorMajor.1.0');
      writePackageConfig(coreVersion: '$generatorMajor.0.0');
      writeReceipt(
        minCoreVersion: '$generatorMajor.1.0',
        generatedAgainstCore: '$generatorMajor.1.0',
      );
      final result = await runCheck();
      expect(result.status, DoctorCheckStatus.fail);
      expect(result.detail, contains('min_core_version'));
      expect(result.detail, contains('make.json'));
      expect(result.suggestedFix, 'dart pub upgrade zuraffa');
    },
  );

  test(
    'pass when receipt floors are satisfied by the installed core',
    () async {
      // The pin must agree with the running CLI major or the advisory
      // triangle reports a stale pin instead of the floor verdict.
      writePubspec(pin: '^$version');
      writePackageConfig(coreVersion: version);
      writeReceipt(
        minCoreVersion: supportedCoreFloor,
        generatedAgainstCore: '$generatorMajor.0.0',
      );
      final result = await runCheck();
      expect(result.status, DoctorCheckStatus.pass);
    },
  );

  test('warn (not fail) when no installed core is resolvable', () async {
    writePubspec(pin: '^$version');
    final result = await runCheck();
    expect(result.status, DoctorCheckStatus.warn);
    expect(result.detail, contains('not resolved'));
  });
}
