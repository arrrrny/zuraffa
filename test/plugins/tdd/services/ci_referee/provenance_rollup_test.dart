// US2 (spec 070): the provenance rollup — per-feature and corpus-wide
// generated/mock/hand-delta ratios, 100% receipt-verified (FR-003,
// SC-002), with archival of previous ratios (FR-012) and the
// receipt-unknown marking (FR-009).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/feature_provenance.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/provenance_rollup.dart';

void main() {
  late Directory root;
  late ProvenanceRollupBuilder builder;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rollup_');
    builder = ProvenanceRollupBuilder(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<String> writeFile(String rel, String content) async {
    final file = File(p.join(root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return rel;
  }

  Future<void> writeFeature({
    required String feature,
    required String subject,
    required bool green,
    bool simulated = false,
    bool drift = false,
  }) async {
    await writeFile(
      'specs/$feature/tdd/artifacts.json',
      jsonEncode({
        'records': [
          {
            'behavior_id': 'B-001',
            'feature': feature,
            'source_criterion': 'FR-001',
            'test_path': 'test/${feature}_test.dart',
            'subject_path': subject,
            'runnable_test_name': 'file::B-001::does it',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-09-01T00:00:00Z',
          },
        ],
      }),
    );
    final content = drift ? 'class S { int drift = 1; }\n' : 'class S {}\n';
    await writeFile(subject, content);
    if (green) {
      await writeFile(
        'specs/$feature/tdd/cycle-log.md',
        '## Cycle: B-001 (green)\n\n- behavior: B-001\n- kind: green\n',
      );
    }
    if (simulated) {
      await writeFile(
        'specs/$feature/tdd/fixtures/manifest.json',
        jsonEncode({
          'families': ['rest'],
          'digest': 'x',
          'files': [],
        }),
      );
    }
    // Receipt over the ORIGINAL (undrifted) bytes.
    final original = drift ? 'class S {}\n' : content;
    final store = ReceiptStore(projectRoot: root.path);
    await store.save(
      GenerationReceipt(
        command: 'tdd-gen',
        target: feature,
        repro: 'zfa tdd gen',
        at: DateTime.utc(2026, 9, 2),
        generatorVersion: '6.1.0',
        input: const {},
        files: [
          GenerationReceiptFile(
            path: subject,
            action: 'create',
            sha256: sha256.convert(original.codeUnits).toString(),
            bytes: original.length,
          ),
        ],
      ),
    );
  }

  test(
    'A4: a corpus of 10 features (8 generated, 1 hand-delta, 1 '
    'hand-written) reports 80%/10%/10% with per-feature breakdowns',
    () async {
      for (var i = 1; i <= 8; i++) {
        await writeFeature(
          feature: 'f-gen-$i',
          subject: 'lib/gen/file$i.dart',
          green: true,
        );
      }
      await writeFeature(
        feature: 'f-delta',
        subject: 'lib/delta/cart.dart',
        green: true,
        drift: true,
      );
      // f-hand: fully hand-written — artifacts + green evidence, but NO
      // receipt ever covered its subject.
      await writeFile(
        'specs/f-hand/tdd/artifacts.json',
        jsonEncode({
          'records': [
            {
              'behavior_id': 'B-001',
              'feature': 'f-hand',
              'source_criterion': 'FR-001',
              'test_path': 'test/f-hand_test.dart',
              'subject_path': 'lib/hand/manual.dart',
              'runnable_test_name': 'file::B-001::does it',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-09-01T00:00:00Z',
            },
          ],
        }),
      );
      await writeFile('lib/hand/manual.dart', 'class Manual {}\n');
      await writeFile(
        'specs/f-hand/ttd/cycle-log.md'.replaceAll('ttd', 'tdd'),
        '## Cycle: B-001 (green)\n\n- behavior: B-001\n- kind: green\n',
      );

      final rollup = await builder.build();

      expect(rollup.corpus.generatedPercent, 80);
      expect(rollup.corpus.handDeltaPercent, 10);
      expect(rollup.corpus.handWrittenPercent, 10);
      expect(rollup.perFeature, hasLength(10));
      expect(
        rollup.perFeature
            .firstWhere((f) => f.feature == 'f-delta')
            .buckets
            .handDelta,
        1,
      );
      expect(
        rollup.perFeature
            .firstWhere((f) => f.feature == 'f-gen-1')
            .buckets
            .generated,
        1,
      );
      // The hand-written feature is NOT guessed at — it is named.
      expect(
        rollup.perFeature.firstWhere((f) => f.feature == 'f-hand').state,
        FeatureRealizationState.receiptUnknown,
      );
    },
  );

  test('A5: every ratio is 100% receipt-verified — each feature row carries '
      'receipt ids and a verification flag (SC-002)', () async {
    await writeFeature(
      feature: 'f-real',
      subject: 'lib/real/a.dart',
      green: true,
    );
    await writeFeature(
      feature: 'f-mock',
      subject: 'lib/mock/a.dart',
      green: true,
      simulated: true,
    );

    final rollup = await builder.build();

    expect(rollup.receiptVerified, isTrue);
    for (final feature in rollup.perFeature) {
      expect(
        feature.receiptIds,
        isNotEmpty,
        reason: '${feature.feature} must trace to receipts',
      );
      expect(feature.receiptVerified, isTrue);
    }
    // Mock vs generated split surfaces in the buckets.
    expect(rollup.corpus.mockPercent, 50);
    expect(rollup.corpus.generatedPercent, 50);
    // The rollup machine document carries the audit trail.
    expect(rollup.toJson()['receipt_verified'], isTrue);
  });

  test('A6: regenerating archives the previous ratios for historical '
      'comparison (FR-012)', () async {
    await writeFeature(
      feature: 'f-real',
      subject: 'lib/real/a.dart',
      green: true,
    );
    final first = await builder.build();
    expect(first.archivedFrom, isNull, reason: 'first run, nothing to archive');

    // New receipt data: one more feature appears.
    await writeFeature(
      feature: 'f-more',
      subject: 'lib/more/a.dart',
      green: true,
    );
    final second = await builder.build();
    expect(
      second.archivedFrom,
      isNotNull,
      reason: 'previous ratios archived on regeneration',
    );
    expect(second.archivedFrom!['corpus']['generated_percent'], 100);
    expect(second.perFeature, hasLength(2));
    expect(second.corpus.generatedPercent, 100);

    // The archive file exists on disk and holds the previous ratios.
    final archiveDir = Directory(
      p.join(root.path, '.zfa', 'corpus', 'provenance-archive'),
    );
    expect(archiveDir.existsSync(), isTrue);
    expect(archiveDir.listSync().whereType<File>(), isNotEmpty);
  });

  test('an empty corpus with no receipts shows the empty state, never '
      'crashes (edge case)', () async {
    final rollup = await builder.build();
    expect(rollup.isEmpty, isTrue);
    expect(rollup.perFeature, isEmpty);
    expect(rollup.corpus.totalFeatures, 0);
    expect(rollup.toJson()['empty'], isTrue);
  });

  test('the machine-readable document is written under .zfa/corpus/ '
      '(assumption: persistent location)', () async {
    await writeFeature(
      feature: 'f-real',
      subject: 'lib/real/a.dart',
      green: true,
    );
    final rollup = await builder.build();
    final doc = File(
      p.join(root.path, '.zfa', 'corpus', 'provenance-rollup.json'),
    );
    expect(await doc.exists(), isTrue);
    final decoded = jsonDecode(await doc.readAsString()) as Map;
    expect(decoded['corpus'], isA<Map>());
    expect(decoded['per_feature'], isA<List>());
    expect(rollup.path, doc.path);
  });
}
