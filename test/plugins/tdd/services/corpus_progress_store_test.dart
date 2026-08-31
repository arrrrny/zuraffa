// Tests for CorpusProgressStore (spec 051, U1-U6).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_feature_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_progress_store.dart';

void main() {
  late Directory tmpDir;
  late CorpusProgressStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('corpus_progress_test_');
    store = CorpusProgressStore(
      tmpDir.path,
      pidAlive: (pid) => false, // dead pid by default
    );
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('CorpusProgressStore', () {
    test('[U1] saves and loads corpus progress atomically', () async {
      final progress = CorpusProgress(
        features: {
          '001-ready': const CorpusFeatureProgress(
            name: '001-ready',
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ),
        },
        inFlight: true,
        ownerPid: 12345,
        startedAt: '2026-08-31T12:00:00Z',
      );
      await store.save(progress);
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.features.length, 1);
      expect(loaded.features['001-ready']?.state, CorpusFeatureState.done);
      expect(loaded.features['001-ready']?.gateOutcome, 'PASS');
      expect(loaded.inFlight, true);
      expect(loaded.ownerPid, 12345);
    });

    test('[U2] detects corrupt progress JSON', () async {
      final file = File(p.join(tmpDir.path, '.zfa', 'corpus', 'progress.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString('not valid json {{{');
      expect(
        () => store.load(),
        throwsA(isA<CorpusProgressCorruptException>()),
      );
    });

    test('[U3] refuses concurrent run when in-flight pid is alive', () async {
      final aliveStore = CorpusProgressStore(
        tmpDir.path,
        pidAlive: (pid) => pid == 99999, // alive
      );
      final progress = CorpusProgress(
        inFlight: true,
        ownerPid: 99999,
      );
      await aliveStore.save(progress);
      final loaded = await aliveStore.load();
      final refusal = aliveStore.refusalReason(loaded);
      expect(refusal, isNotNull);
      expect(refusal, contains('corpus run is already in flight'));
    });

    test('[U4] allows resume when in-flight pid is dead', () async {
      final progress = CorpusProgress(
        inFlight: true,
        ownerPid: 99999, // dead pid
      );
      await store.save(progress);
      final loaded = await store.load();
      final refusal = store.refusalReason(loaded);
      expect(refusal, isNull);
    });

    test('[U5] computes resume point as first non-done/not-ready/dropped', () async {
      final features = {
        '001-done': const CorpusFeatureProgress(
          name: '001-done',
          state: CorpusFeatureState.done,
        ),
        '002-pending': const CorpusFeatureProgress(name: '002-pending'),
        '003-not-ready': const CorpusFeatureProgress(
          name: '003-not-ready',
          state: CorpusFeatureState.notReady,
        ),
      };
      final resume = store.resumePoint(
        ['001-done', '002-pending', '003-not-ready'],
        features,
      );
      expect(resume, '002-pending');
    });

    test('[U5] returns null when all features are done', () async {
      final features = {
        '001': const CorpusFeatureProgress(
          name: '001',
          state: CorpusFeatureState.done,
        ),
      };
      final resume = store.resumePoint(['001'], features);
      expect(resume, isNull);
    });

    test('[U6] tracks dropped features', () async {
      final progress = CorpusProgress(
        features: {
          '001': const CorpusFeatureProgress(
            name: '001',
            state: CorpusFeatureState.dropped,
          ),
          '002': const CorpusFeatureProgress(name: '002'),
        },
      );
      await store.save(progress);
      final loaded = await store.load();
      expect(loaded!.features['001']?.state, CorpusFeatureState.dropped);
      expect(loaded.features['002']?.state, CorpusFeatureState.pending);
    });
  });
}
