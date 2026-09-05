import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/receipt_preflight.dart';

/// Spec 0996 (issue #996), FR-005 — `zfa tdd verify` includes
/// receipt-checking as a preflight gate.
///
/// Unit tier (this file, FAST): the [ReceiptPreflight] verdict itself —
///   * no receipts in the project → vacuous pass (backward compat),
///   * receipts present + audited subject covered and valid → pass,
///   * receipts present + audited subject WITHOUT a receipt → FAIL
///     ("missing receipt" — the gate the issue demands),
///   * receipts present but drifted / artifact deleted → FAIL.
///
/// CLI tier: `zfa tdd verify` runs the gate BEFORE the mutation audit and
/// exits non-zero on gate failure.
void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_996_preflight_');
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: preflight_fixture
environment:
  sdk: ^3.11.0
''');
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  Future<File> writeSubject([String path = 'lib/tdd/b_001_subject.dart']) =>
      File(p.join(workspace.path, path))
          .create(recursive: true)
          .then((f) => f.writeAsString('int add(int a, int b) => a + b;\n'));

  Future<void> seedReceipt(List<String> coveredPaths) async {
    final files = <GenerationReceiptFile>[];
    for (final path in coveredPaths) {
      final bytes = File(p.join(workspace.path, path)).readAsBytesSync();
      files.add(
        GenerationReceiptFile(
          path: path,
          action: 'create',
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
        ),
      );
    }
    await ReceiptStore(projectRoot: workspace.path).save(
      GenerationReceipt(
        command: 'di create',
        target: 'Subject',
        repro: 'zfa di create Subject',
        at: DateTime.utc(2026, 9, 5, 10),
        generatorVersion: 'test',
        input: const {},
        plugin: 'di',
        capability: 'create',
        entity: 'Subject',
        methodset: const [],
        runHash: '0' * 64,
        files: files,
      ),
    );
  }

  group('unit — ReceiptPreflight verdict (spec 0996 FR-005)', () {
    test(
      'no receipts shipped → vacuous pass (backward compatibility)',
      () async {
        await writeSubject();

        final report = await ReceiptPreflight(
          projectRoot: workspace.path,
        ).check(auditedPaths: ['lib/tdd/b_001_subject.dart']);

        expect(report.ok, isTrue);
        expect(report.gateActive, isFalse, reason: 'nothing to check');
        expect(report.receipts, 0);
        expect(report.findings, isEmpty);
      },
    );

    test('receipt-covered, valid subject → pass', () async {
      await writeSubject();
      await seedReceipt(['lib/tdd/b_001_subject.dart']);

      final report = await ReceiptPreflight(
        projectRoot: workspace.path,
      ).check(auditedPaths: ['lib/tdd/b_001_subject.dart']);

      expect(report.ok, isTrue);
      expect(report.gateActive, isTrue);
      expect(report.receipts, 1);
    });

    test('missing receipt for an audited subject → GATE FAILURE', () async {
      // The project ships receipts (proof-carrying generation in use) but
      // no receipt proves the audited subject — issue #996's gate.
      await writeSubject();
      await writeSubject('lib/src/other.dart');
      await seedReceipt(['lib/src/other.dart']);

      final report = await ReceiptPreflight(
        projectRoot: workspace.path,
      ).check(auditedPaths: ['lib/tdd/b_001_subject.dart']);

      expect(report.ok, isFalse);
      expect(report.findings, hasLength(1));
      expect(report.findings.single.kind, 'missing_receipt');
      expect(report.findings.single.path, 'lib/tdd/b_001_subject.dart');
      expect(report.findings.single.detail, contains('no receipt'));
    });

    test('the missing-receipt finding names the store and the subject '
        'exactly (machine-readable detail)', () async {
      await writeSubject();
      await writeSubject('lib/src/other.dart');
      await seedReceipt(['lib/src/other.dart']);

      final report = await ReceiptPreflight(
        projectRoot: workspace.path,
      ).check(auditedPaths: ['lib/tdd/b_001_subject.dart']);

      expect(report.ok, isFalse);
      expect(
        report.findings.single.detail,
        contains('.zfa/receipts/ covers this audit subject'),
        reason:
            'agents parse the finding detail - the store path and the '
            'subject wording are the contract',
      );
    });

    test('backslash-separated audited paths are normalized before the '
        'coverage check', () async {
      await writeSubject();
      await seedReceipt(['lib/tdd/b_001_subject.dart']);

      final report = await ReceiptPreflight(
        projectRoot: workspace.path,
      ).check(auditedPaths: [r'lib\tdd\b_001_subject.dart']);

      expect(
        report.ok,
        isTrue,
        reason:
            'a Windows-style subject path must still match its '
            'receipt-covered POSIX form',
      );
    });

    test(
      'drifted receipt (subject modified after the run) → GATE FAILURE',
      () async {
        await writeSubject();
        await seedReceipt(['lib/tdd/b_001_subject.dart']);
        await File(
          p.join(workspace.path, 'lib', 'tdd', 'b_001_subject.dart'),
        ).writeAsString('int sub(int a, int b) => a - b;\n');

        final report = await ReceiptPreflight(
          projectRoot: workspace.path,
        ).check(auditedPaths: ['lib/tdd/b_001_subject.dart']);

        expect(report.ok, isFalse);
        expect(report.findings, isNotEmpty);
        expect(
          report.findings.first.kind,
          anyOf('modified', 'invalid_receipt'),
        );
      },
    );

    test('receipted artifact deleted → GATE FAILURE', () async {
      await writeSubject();
      await seedReceipt(['lib/tdd/b_001_subject.dart']);
      await File(
        p.join(workspace.path, 'lib', 'tdd', 'b_001_subject.dart'),
      ).delete();

      final report = await ReceiptPreflight(
        projectRoot: workspace.path,
      ).check(auditedPaths: const []);

      expect(report.ok, isFalse);
      expect(report.findings.first.kind, 'deleted');
    });
  });

  group('CLI — zfa tdd verify receipt preflight gate', () {
    late Directory fixtureRoot;
    late String featureDir;
    const featureName = '090-spec-996';

    setUp(() {
      fixtureRoot = Directory.systemTemp.createTempSync('zfa_996_verify_');
      featureDir = p.join(fixtureRoot.path, 'specs', featureName);
      File(p.join(fixtureRoot.path, 'lib', 'tdd', 'b_001_subject.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('int add(int a, int b) => a + b;\n');
      File(p.join(featureDir, 'tdd', 'artifacts.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'feature': featureName,
            'records': [
              {
                'behavior_id': 'B-001',
                'feature': featureName,
                'source_criterion': 'FR-005',
                'test_path': 'test/tdd/b_001_test.dart',
                'subject_path': 'lib/tdd/b_001_subject.dart',
                'runnable_test_name': 'x::B-001::y',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-05T00:00:00.000Z',
              },
            ],
          }),
        );
      // Make the mutation phase cheaply unresolvable so a PASSING receipt
      // gate is observable via the audit's own NOT_ASSESSED verdict —
      // the gate ran and let the audit proceed.
      File(p.join(fixtureRoot.path, '.dart_tool')).writeAsStringSync('file');
    });

    tearDown(() {
      exitCode = 0;
      if (fixtureRoot.existsSync()) {
        fixtureRoot.deleteSync(recursive: true);
      }
    });

    test('missing receipt for the audited subject → gate failure, exit 1, '
        'no mutation audit', () async {
      // Receipts exist (the project ships proof) but none covers the
      // audited subject.
      final other = File(p.join(fixtureRoot.path, 'lib', 'src', 'other.dart'));
      other.parent.createSync(recursive: true);
      await other.writeAsString('// other\n');
      final bytes = other.readAsBytesSync();
      await ReceiptStore(projectRoot: fixtureRoot.path).save(
        GenerationReceipt(
          command: 'service create',
          target: 'Other',
          repro: 'zfa service create Other',
          at: DateTime.utc(2026, 9, 5, 9),
          generatorVersion: 'test',
          input: const {},
          files: [
            GenerationReceiptFile(
              path: 'lib/src/other.dart',
              action: 'create',
              sha256: crypto.sha256.convert(bytes).toString(),
              bytes: bytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await _runVerify(runner, fixtureRoot.path, featureName);

      expect(out, contains('receipt preflight'));
      expect(out, contains('missing_receipt'));
      expect(out, contains('lib/tdd/b_001_subject.dart'));
      expect(exitCode, 1, reason: 'gate failure must exit non-zero');
      expect(
        out,
        isNot(contains('running mutation audit')),
        reason: 'the audit must never start after a receipt gate failure',
      );
    });

    test('green receipt gate lets the audit proceed', () async {
      final bytes = File(
        p.join(fixtureRoot.path, 'lib', 'tdd', 'b_001_subject.dart'),
      ).readAsBytesSync();
      await ReceiptStore(projectRoot: fixtureRoot.path).save(
        GenerationReceipt(
          command: 'di create',
          target: 'Subject',
          repro: 'zfa di create Subject',
          at: DateTime.utc(2026, 9, 5, 9),
          generatorVersion: 'test',
          input: const {},
          files: [
            GenerationReceiptFile(
              path: 'lib/tdd/b_001_subject.dart',
              action: 'create',
              sha256: crypto.sha256.convert(bytes).toString(),
              bytes: bytes.length,
            ),
          ],
        ),
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await _runVerify(runner, fixtureRoot.path, featureName);

      expect(out, contains('receipt preflight: ok'));
      expect(
        out,
        contains('mutation config'),
        reason:
            'the audit itself must run past the gate (its NOT_ASSESSED '
            'config verdict is the observable proof)',
      );
    });

    test('no receipts shipped → gate vacuous, audit proceeds '
        '(legacy projects keep working)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await _runVerify(runner, fixtureRoot.path, featureName);

      expect(out, isNot(contains('receipt preflight — FAIL')));
      expect(out, isNot(contains('missing_receipt')));
      expect(out, contains('mutation config'));
    });
  });
}

Future<String> _runVerify(
  CliRunner runner,
  String projectRoot,
  String feature,
) async {
  try {
    return await runner.runCapturing([
      'tdd',
      'verify',
      '--project',
      projectRoot,
      '--feature',
      feature,
    ]);
  } on UsageException catch (e) {
    return e.message;
  } on StateError catch (e) {
    return e.message;
  }
}
