/// Issue #969 (T003/T004) — proof.v1 receipts on the TDD generation
/// verbs + the verify preflight proof gate.
///
/// Acceptance contract:
///   * the plan→gen cycle leaves every generated artifact receipted
///     (digest-bound proof.v1 documents under `.zfa/receipts/`);
///   * `zfa proof check` exits 0 on a fresh cycle and exits 1 when an
///     artifact is hand-edited afterwards;
///   * `zfa tdd verify` runs the proof preflight BEFORE the mutation
///     audit — digest drift in the feature's artifacts → NOT_ASSESSED
///     verdict, exit 3, and a `--> fix:` line;
///   * a clean feature passes the preflight (the audit runs).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';

import 'helpers/spec_fixture.dart';

void main() {
  late Directory tmp;
  const feature = '090-tdd-fixture';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug969_receipts_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> run(List<String> args) {
    // Direct CliRunner use keeps the global exitCode for assertions.
    return CliRunner(exitOnCompletion: false).runCapturing(args);
  }

  group('issue #969 T003 — receipts on the generation verbs', () {
    test('plan receipts test-list.md and traceability.md', () async {
      final featureDir = p.join(tmp.path, 'specs', feature);
      await Directory(featureDir).create(recursive: true);
      await writeSpec(featureDir, kMinimalAcceptance);

      await run(['tdd', 'plan', feature, '--project', tmp.path]);

      final store = ReceiptStore(projectRoot: tmp.path);
      final records = await store.loadAll();
      final receiptedPaths = records
          .expand((r) => r.receipt.files.map((e) => e.path))
          .toSet();
      expect(
        receiptedPaths,
        containsAll([
          'specs/$feature/tdd/test-list.md',
          'specs/$feature/tdd/traceability.md',
        ]),
        reason: 'the plan artifacts must be digest-bound receipts',
      );
      final planReceipts = records
          .where((r) => r.receipt.command == 'tdd plan')
          .toList();
      expect(planReceipts, isNotEmpty);
      expect(planReceipts.first.receipt.input['feature'], feature);
      expect(planReceipts.first.receipt.schema, 'proof.v1');
    });

    test('gen receipts the generated test/subject pair', () async {
      final specDir = p.join(tmp.path, 'specs', feature);
      await Directory(p.join(specDir, 'tdd')).create(recursive: true);
      await File(p.join(specDir, 'spec.md')).writeAsString('''
# Spec for $feature

## Functional Requirements

- **FR-001**: the pdf-to-markdown ffi binding converts a sample pdf
''');
      await File(p.join(specDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List for $feature

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | the pdf-to-markdown ffi binding converts a sample pdf | FR-001 | PENDING |
''');

      await run([
        'tdd',
        'gen',
        'U1',
        '--project',
        tmp.path,
        '--feature',
        feature,
      ]);

      final testFile = File(
        p.join(tmp.path, 'test', 'tdd', feature, 'u1_test.dart'),
      );
      expect(testFile.existsSync(), isTrue);
      final subjectFile = File(
        p.join(tmp.path, 'lib', 'tdd', feature, 'u1_subject.dart'),
      );
      expect(subjectFile.existsSync(), isTrue);

      final store = ReceiptStore(projectRoot: tmp.path);
      final records = await store.loadAll();
      final genReceipts = records
          .where((r) => r.receipt.command == 'tdd gen')
          .toList();
      expect(genReceipts, isNotEmpty, reason: 'gen must write a receipt');
      final receiptedPaths = genReceipts
          .expand((r) => r.receipt.files.map((e) => e.path))
          .toSet();
      expect(
        receiptedPaths,
        containsAll([
          'test/tdd/$feature/u1_test.dart',
          'lib/tdd/$feature/u1_subject.dart',
        ]),
        reason: 'the generated test/subject pair must be receipted',
      );
    });
  });

  group('issue #969 — zfa proof check on a fresh cycle', () {
    test('exits 0 on fresh cycle artifacts, 1 after a hand-edit', () async {
      final featureDir = p.join(tmp.path, 'specs', feature);
      await Directory(featureDir).create(recursive: true);
      await writeSpec(featureDir, kMinimalAcceptance);
      await run(['tdd', 'plan', feature, '--project', tmp.path]);

      // Fresh cycle: the receipted bytes are the on-disk bytes.
      final out = await run(['-C', tmp.path, 'proof', 'check']);
      expect(exitCode, 0, reason: 'fresh cycle must prove clean: $out');

      // Hand-edit a receipted artifact: digest drift = exit 1.
      final testList = File(
        p.join(tmp.path, 'specs', feature, 'tdd', 'test-list.md'),
      );
      await testList.writeAsString(
        (await testList.readAsString()).replaceFirst('PENDING', 'DONE'),
      );
      final out2 = await run(['-C', tmp.path, 'proof', 'check']);
      expect(
        exitCode,
        1,
        reason: 'a hand-edited artifact must fail proof check: $out2',
      );
    });
  });

  group('issue #969 T004 — verify proof preflight gate', () {
    test('digest drift → NOT_ASSESSED verdict, exit 3, --> fix line', () async {
      final featureDir = p.join(tmp.path, 'specs', feature);
      await Directory(featureDir).create(recursive: true);
      await writeSpec(featureDir, kMinimalAcceptance);
      await run(['tdd', 'plan', feature, '--project', tmp.path]);

      // Hand-edit AFTER the cycle: the preflight must refuse.
      final testList = File(
        p.join(tmp.path, 'specs', feature, 'tdd', 'test-list.md'),
      );
      await testList.writeAsString(
        (await testList.readAsString()).replaceFirst('PENDING', 'DONE'),
      );

      final out = await run([
        'tdd',
        'verify',
        '--feature',
        feature,
        '--project',
        tmp.path,
      ]);

      expect(exitCode, 3, reason: 'digest drift is non-zero: $out');
      expect(out, contains('NOT_ASSESSED'));
      expect(out, contains('--> fix:'));
      expect(
        out,
        isNot(contains('running mutation audit')),
        reason: 'the preflight fires BEFORE the mutation audit',
      );
    });

    test(
      'a clean feature passes the preflight and reaches the audit',
      () async {
        final featureDir = p.join(tmp.path, 'specs', feature);
        await Directory(featureDir).create(recursive: true);
        await writeSpec(featureDir, kMinimalAcceptance);
        await run(['tdd', 'plan', feature, '--project', tmp.path]);

        final out = await run([
          'tdd',
          'verify',
          '--feature',
          feature,
          '--project',
          tmp.path,
        ]);

        expect(
          out,
          contains('running mutation audit'),
          reason: 'no digest drift — the preflight must let the audit run',
        );
      },
    );
  });
}
