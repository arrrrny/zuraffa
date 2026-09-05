import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_engine_command.dart';

/// Spec 1001 (issue #1001), deliverable 3: `zfa tdd run-engine` refuses
/// to proceed if any CORE entity's mock is uncertified.
///
/// CORE entities are the feature's declared Key Entities (the entities
/// the run driver's phase 0 orchestrates). Gate semantics per entity:
/// no mock on disk → proceed; mock + all-satisfied receipt → certified;
/// mock present but receipt missing/corrupt/unsatisfied → refuse.
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String featureDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_run_engine_');
    projectRoot = tempDir.path;
    featureDir = p.join(projectRoot, 'specs', '1001-mock-gate');
    final tddDir = Directory(p.join(featureDir, 'tdd'));
    tddDir.createSync(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeTestList(List<String> entities) {
    final buffer = StringBuffer()
      ..writeln('# Test list')
      ..writeln()
      ..writeln('## Key Entities')
      ..writeln()
      ..writeln('| Entity | Fields |')
      ..writeln('| --- | --- |')
      ..writeln('| | |');
    for (final entity in entities) {
      buffer.writeln('| $entity | id:String |');
    }
    File(
      p.join(featureDir, 'tdd', 'test-list.md'),
    ).writeAsStringSync(buffer.toString());
  }

  void writeMockDatasource(String entityName) {
    final snake = entityName.toLowerCase();
    final dsDir = Directory(
      p.join(projectRoot, 'lib', 'src', 'data', 'datasources', snake),
    );
    dsDir.createSync(recursive: true);
    File(
      p.join(dsDir.path, '${snake}_mock_datasource.dart'),
    ).writeAsStringSync('// GENERATED - DO NOT EDIT\n');
  }

  void writeReceipt(String entityName, {required bool allSatisfied}) {
    final snake = entityName.toLowerCase();
    final dir = Directory(p.join(projectRoot, 'test', 'mock', snake));
    dir.createSync(recursive: true);
    final methods = [
      'get',
      'update',
      'toggle',
    ].map((m) => {'name': m, 'satisfied': allSatisfied}).toList();
    File(p.join(dir.path, 'mock-cert.$entityName.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'spec': 1001,
        'entity': entityName,
        'interface': '${entityName}DataSource',
        'contract_digest': 'abc123',
        'methods': methods,
        'sandbox': const {
          'runner': 'dart',
          'analyze_issues': 0,
          'analyze_errors': 0,
        },
        'certified_at': '2026-09-04T00:00:00.000Z',
      }),
    );
  }

  group('run-engine gate (spec 1001)', () {
    test('no mocks on disk → nothing to enforce, gate ok', () async {
      writeTestList(['Login', 'Session']);
      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isTrue);
      expect(result.coreEntities, ['Login', 'Session']);
      expect(result.mocks, isEmpty);
      expect(result.uncertified, isEmpty);
    });

    test('mock + all-satisfied receipt → certified, gate ok', () async {
      writeTestList(['Login']);
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: true);

      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isTrue);
      expect(result.mocks, ['Login']);
      expect(result.certified, ['Login']);
      expect(result.uncertified, isEmpty);
    });

    test('mock present but no receipt → refuses, names the entity', () async {
      writeTestList(['Login', 'Session']);
      writeMockDatasource('Login');
      writeMockDatasource('Session');
      writeReceipt('Login', allSatisfied: true);
      // Session: mock exists, receipt missing.

      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isFalse);
      expect(result.uncertified, ['Session']);
      expect(result.blockedEntity, 'Session');
    });

    test('mock + receipt with an unsatisfied method → refuses', () async {
      writeTestList(['Login']);
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: false);

      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isFalse);
      expect(result.blockedEntity, 'Login');
    });

    test('mock + corrupt receipt → refuses (not a certification)', () async {
      writeTestList(['Login']);
      writeMockDatasource('Login');
      final dir = Directory(p.join(projectRoot, 'test', 'mock', 'login'));
      dir.createSync(recursive: true);
      File(
        p.join(dir.path, 'mock-cert.Login.json'),
      ).writeAsStringSync('garbage');

      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isFalse);
      expect(result.blockedEntity, 'Login');
    });

    test('entities without declared mock paths are not gated', () async {
      // An entity declared in the feature but WITHOUT a mock datasource
      // on disk never blocks the engine — mocks are generated by the
      // loop, not required up front.
      writeTestList(['Login', 'Billing']);
      writeMockDatasource('Login');
      writeReceipt('Login', allSatisfied: true);
      // Billing: no mock file.

      final result = await RunEngineCommand.checkFeature(
        projectRoot: projectRoot,
        featureDir: featureDir,
      );

      expect(result.ok, isTrue);
      expect(result.coreEntities, hasLength(2));
      expect(result.mocks, ['Login']);
    });

    test(
      'feature without a Key Entities section → empty core set, ok',
      () async {
        File(
          p.join(featureDir, 'tdd', 'test-list.md'),
        ).writeAsStringSync('# Test list\n\n## Behaviors\n\n- U1: something\n');
        final result = await RunEngineCommand.checkFeature(
          projectRoot: projectRoot,
          featureDir: featureDir,
        );
        expect(result.ok, isTrue);
        expect(result.coreEntities, isEmpty);
      },
    );
  });
}
