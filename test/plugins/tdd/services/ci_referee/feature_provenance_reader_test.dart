// U1-U6 (spec 070): the provenance reader — derives per-feature state and
// receipt-verified ratios from the recorded infrastructure (#807 receipt
// ledger, 044 artifact registries, cycle-log evidence, #832 simulation
// fixture manifests, 051 corpus progress). Read-only by contract.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/feature_provenance.dart';
import 'package:zuraffa/src/plugins/tdd/services/ci_referee/feature_provenance_reader.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ci_referee_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  // ---- fixture builders ------------------------------------------------

  Future<String> writeFile(String rel, String content) async {
    final file = File(p.join(root.path, rel));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return rel;
  }

  Future<void> writeArtifacts(
    String feature,
    List<(String, String)> behaviors,
  ) async {
    final records = [
      for (final (behavior, subject) in behaviors)
        {
          'behavior_id': behavior,
          'feature': feature,
          'source_criterion': 'FR-001',
          'test_path': 'test/${feature}_${behavior}_test.dart',
          'subject_path': subject,
          'runnable_test_name': 'file::$behavior::does the thing',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': '2026-09-01T00:00:00Z',
        },
    ];
    await writeFile(
      'specs/$feature/tdd/artifacts.json',
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'schema': 'artifacts.v1', 'records': records}),
    );
  }

  Future<void> writeCycleLog(
    String feature,
    List<String> greenBehaviors,
  ) async {
    final buf = StringBuffer('# Cycle Log\n');
    for (final b in greenBehaviors) {
      buf
        ..writeln('## Cycle: $b (green)')
        ..writeln()
        ..writeln('- behavior: $b')
        ..writeln('- kind: green')
        ..writeln('- exit: 0')
        ..writeln();
    }
    await writeFile('specs/$feature/tdd/cycle-log.md', buf.toString());
  }

  Future<void> writeReceipt(List<String> relPaths) async {
    final files = <GenerationReceiptFile>[];
    for (final rel in relPaths) {
      final bytes = await File(p.join(root.path, rel)).readAsBytes();
      files.add(
        GenerationReceiptFile(
          path: rel,
          action: 'create',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
        ),
      );
    }
    final store = ReceiptStore(projectRoot: root.path);
    await store.save(
      GenerationReceipt(
        command: 'tdd-gen',
        target: 'feature',
        repro: 'zfa tdd gen',
        at: DateTime.utc(2026, 9, 2),
        generatorVersion: '6.1.0',
        input: const {},
        files: files,
      ),
    );
  }

  Future<void> writeSimulationFixtures(String feature) async {
    await writeFile(
      'specs/$feature/tdd/fixtures/manifest.json',
      jsonEncode({
        'feature': feature,
        'families': ['rest'],
        'digest': 'deadbeef',
        'files': [],
      }),
    );
  }

  Future<void> writeCorpusProgress(Map<String, String> featureStates) async {
    await writeFile(
      '.zfa/corpus/progress.json',
      jsonEncode({
        'features': {
          for (final e in featureStates.entries) e.key: {'state': e.value},
        },
        'dropped': [],
      }),
    );
  }

  Future<List<FeatureProvenance>> read() =>
      FeatureProvenanceReader(root.path).read();

  // ---- tests ------------------------------------------------------------

  test('U1: derives complete(real) for a fully realized feature with '
      'receipt-backed, undrifted files', () async {
    await writeArtifacts('f-real', [('B-001', 'lib/real/cart.dart')]);
    await writeCycleLog('f-real', ['B-001']);
    await writeFile('lib/real/cart.dart', 'class Cart {}\n');
    await writeReceipt(['lib/real/cart.dart']);

    final features = await read();
    final real = features.firstWhere((f) => f.feature == 'f-real');
    expect(real.state, FeatureRealizationState.completeReal);
    expect(real.buckets.generated, 1);
    expect(real.buckets.mock, 0);
    expect(real.buckets.handDelta, 0);
    expect(real.receiptCount, 1);
    expect(real.handDeltaReceipts, 0);
    expect(real.receiptVerified, isTrue, reason: 'SC-002: traced to a receipt');
    expect(real.receiptIds, isNotEmpty);
  });

  test('U2: derives complete(mocked) for a feature with a committed simulation '
      'fixture manifest (#832 binding)', () async {
    await writeArtifacts('f-mock', [('B-001', 'lib/mock/api.dart')]);
    await writeCycleLog('f-mock', ['B-001']);
    await writeFile('lib/mock/api.dart', 'class Api {}\n');
    await writeSimulationFixtures('f-mock');
    await writeReceipt(['lib/mock/api.dart']);

    final features = await read();
    final mock = features.firstWhere((f) => f.feature == 'f-mock');
    expect(mock.state, FeatureRealizationState.completeMocked);
    expect(mock.buckets.mock, 1);
    expect(mock.buckets.generated, 0);
  });

  test('U3: derives realizing for a feature whose behaviors are only partially '
      'green, and for a corpus-driving feature', () async {
    await writeArtifacts('f-mid', [
      ('B-001', 'lib/mid/one.dart'),
      ('B-002', 'lib/mid/two.dart'),
    ]);
    await writeCycleLog('f-mid', ['B-001']);
    await writeFile('lib/mid/one.dart', 'class One {}\n');
    await writeFile('lib/mid/two.dart', 'class Two {}\n');
    // Generation happened (receipts exist); realization is in flight.
    await writeReceipt(['lib/mid/one.dart', 'lib/mid/two.dart']);
    await writeCorpusProgress({'f-mid': 'driving'});

    final features = await read();
    final mid = features.firstWhere((f) => f.feature == 'f-mid');
    expect(mid.state, FeatureRealizationState.realizing);
    expect(mid.releasable, isFalse, reason: 'FR-015: intermediate states');

    // A corpus `driving` state alone (all behaviors green) is still
    // intermediate.
    await writeCycleLog('f-mid', ['B-001', 'B-002']);
    final features2 = await read();
    final mid2 = features2.firstWhere((f) => f.feature == 'f-mid');
    expect(mid2.state, FeatureRealizationState.realizing);
  });

  test('U4: marks receipt-unknown when no receipt covers the feature\'s '
      'registered subjects (FR-009)', () async {
    await writeArtifacts('f-unk', [('B-001', 'lib/unk/thing.dart')]);
    await writeCycleLog('f-unk', ['B-001']);
    await writeFile('lib/unk/thing.dart', 'class Thing {}\n');
    // No receipt written for this feature.

    final features = await read();
    final unk = features.firstWhere((f) => f.feature == 'f-unk');
    expect(unk.state, FeatureRealizationState.receiptUnknown);
    expect(unk.receiptVerified, isFalse);
    expect(unk.releasable, isFalse);
  });

  test(
    'U5: counts receipt digest drift as hand-delta (hand-delta receipts)',
    () async {
      await writeArtifacts('f-delta', [('B-001', 'lib/delta/cart.dart')]);
      await writeCycleLog('f-delta', ['B-001']);
      await writeFile('lib/delta/cart.dart', 'class Cart {}\n');
      // Receipt records the generated bytes...
      await writeReceipt(['lib/delta/cart.dart']);
      // ...then a hand modification drifts the file.
      await writeFile('lib/delta/cart.dart', 'class Cart { int hack = 1; }\n');

      final features = await read();
      final delta = features.firstWhere((f) => f.feature == 'f-delta');
      expect(delta.buckets.handDelta, 1, reason: 'drifted from receipt');
      expect(delta.handDeltaReceipts, 1);
      expect(delta.buckets.generated, 0);
    },
  );

  test(
    'U6: attributes non-featureized code to the shared/infrastructure row',
    () async {
      await writeArtifacts('f-real', [('B-001', 'lib/real/cart.dart')]);
      await writeCycleLog('f-real', ['B-001']);
      await writeFile('lib/real/cart.dart', 'class Cart {}\n');
      await writeReceipt(['lib/real/cart.dart']);
      await writeFile('lib/shared/util.dart', 'void util() {}\n');

      final features = await read();
      final shared = features.firstWhere((f) => f.feature == 'shared');
      expect(shared.buckets.handWritten, greaterThanOrEqualTo(1));
      expect(
        features.where((f) => f.feature == 'f-real'),
        isNotEmpty,
        reason: 'featureized code stays on its own row',
      );
    },
  );

  test('an empty corpus with no receipts yields an empty list, never a crash '
      '(edge case)', () async {
    final features = await read();
    expect(features, isEmpty);
  });
}
