// Tests for CorpusProgressStore + the CorpusProgress model round trip
// (spec 051-corpus-harness, U6-U10).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_progress_store.dart';

void main() {
  late Directory root;
  late CorpusProgressStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('corpus_progress_');
    store = CorpusProgressStore(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  CorpusProgress sampleProgress() => CorpusProgress(
    features: {
      'f1-good': FeatureProgress(
        state: FeatureCorpusState.done,
        gate: 'pass',
      ),
      'f2-gap': FeatureProgress(
        state: FeatureCorpusState.stopped,
        gate: 'fail_survived',
        stoppedAt: 'verify',
      ),
      'f3-waived': FeatureProgress(
        state: FeatureCorpusState.waived,
        gate: 'not_assessed',
        waiver: CorpusWaiver(
          feature: 'f3-waived',
          gate: 'not_assessed',
          reason: 'mutation tool unavailable',
          actor: 'maintainer',
          at: '2026-08-31T01:00:00Z',
        ),
      ),
    },
    inFlight: CorpusInFlight(feature: 'f2-gap', ownerPid: 4242),
    dropped: ['f0-removed'],
  );

  group('CorpusProgress model (U6)', () {
    test('round-trips state, gate, stoppedAt, waiver, in-flight, dropped',
        () {
      final progress = sampleProgress();
      final decoded = jsonDecode(jsonEncode(progress.toJson()));
      final restored = CorpusProgress.fromJson(decoded);
      expect(restored.features.keys, containsAll(progress.features.keys));
      final f1 = restored.features['f1-good']!;
      expect(f1.state, FeatureCorpusState.done);
      expect(f1.gate, 'pass');
      final f2 = restored.features['f2-gap']!;
      expect(f2.state, FeatureCorpusState.stopped);
      expect(f2.gate, 'fail_survived');
      expect(f2.stoppedAt, 'verify');
      final f3 = restored.features['f3-waived']!;
      expect(f3.state, FeatureCorpusState.waived);
      expect(f3.waiver?.reason, 'mutation tool unavailable');
      expect(f3.waiver?.actor, 'maintainer');
      expect(restored.inFlight?.feature, 'f2-gap');
      expect(restored.inFlight?.ownerPid, 4242);
      expect(restored.dropped, ['f0-removed']);
    });

    test('empty progress round-trips to empty', () {
      final restored = CorpusProgress.fromJson(jsonDecode('{}'));
      expect(restored.features, isEmpty);
      expect(restored.inFlight, isNull);
      expect(restored.dropped, isEmpty);
    });
  });

  group('CorpusProgressStore (U7)', () {
    test(
      'a save that fails mid-write leaves the previous file byte-identical',
      () async {
        final first = CorpusProgress(features: {
          'f1': FeatureProgress(state: FeatureCorpusState.done, gate: 'pass'),
        });
        await store.save(first);
        final before = await File(store.path).readAsString();

        // Force the temp-write to fail: occupy the tmp path with a
        // directory so writeAsString cannot succeed.
        final tmp = Directory('${store.path}.tmp');
        await tmp.create(recursive: true);
        final second = CorpusProgress(features: {
          'f1': FeatureProgress(state: FeatureCorpusState.done, gate: 'pass'),
          'f2': FeatureProgress(state: FeatureCorpusState.pending),
        });
        await expectLater(store.save(second), throwsA(isA<FileSystemException>()));
        final after = await File(store.path).readAsString();
        expect(after, before, reason: 'the previous file must survive');
        expect(jsonDecode(after), isA<Map<String, dynamic>>());
      },
    );
  });

  group('CorpusProgressStore (U8)', () {
    test('a corrupt progress file stops naming the file and recovery',
        () async {
      final file = File(store.path);
      await file.parent.create(recursive: true);
      await file.writeAsString('{"features": "not-a-map"}');
      expect(
        () => store.load(),
        throwsA(
          isA<CorpusCorruptException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('progress.json'),
              contains('Recovery'),
              contains('delete'),
            ),
          ),
        ),
      );
    });

    test('invalid JSON text is corruption, not absence', () async {
      final file = File(store.path);
      await file.parent.create(recursive: true);
      await file.writeAsString('{nope');
      expect(() => store.load(), throwsA(isA<CorpusCorruptException>()));
    });

    test('an absent file loads as null (fresh corpus)', () async {
      expect(await store.load(), isNull);
    });
  });

  group('CorpusProgressStore (U9)', () {
    test('a live foreign pid in the marker is refused', () {
      final progress = CorpusProgress(
        inFlight: CorpusInFlight(feature: 'f2-gap', ownerPid: 999999),
      );
      final refusal = store.refusalReason(
        progress,
        pidAlive: (pid) => true,
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('f2-gap'));
      expect(refusal, contains('999999'));
      expect(refusal, contains('refusing'));
    });

    test('own pid, dead pid, and no marker never refuse', () {
      final own = store.refusalReason(
        CorpusProgress(
          inFlight: CorpusInFlight(feature: 'f', ownerPid: pid),
        ),
        pidAlive: (pid) => true,
      );
      expect(own, isNull, reason: 'the owner is this process');

      final dead = store.refusalReason(
        CorpusProgress(
          inFlight: CorpusInFlight(feature: 'f', ownerPid: 999999),
        ),
        pidAlive: (pid) => false,
      );
      expect(dead, isNull, reason: 'the owner is not alive');

      final absent = store.refusalReason(CorpusProgress(), pidAlive: (pid) => true);
      expect(absent, isNull, reason: 'no in-flight marker');
    });
  });

  group('CorpusProgressStore (U10)', () {
    test('features absent from the manifest land in dropped and are kept',
        () async {
      final progress = CorpusProgress(features: {
        'f1': FeatureProgress(state: FeatureCorpusState.done, gate: 'pass'),
        'f0-removed': FeatureProgress(state: FeatureCorpusState.pending),
      });
      await store.save(progress, manifestFeatureNames: {'f1', 'f2-new'});
      final persisted = await store.load();
      expect(persisted!.dropped, ['f0-removed']);
      // The entry itself is retained (append-only audit trail).
      expect(persisted.features.containsKey('f0-removed'), isTrue);
      expect(persisted.features['f1']!.state, FeatureCorpusState.done);
    });
  });

  group('CorpusProgressStore save/load (integration)', () {
    test('save persists and load restores the full shape', () async {
      await store.save(sampleProgress());
      final restored = await store.load();
      expect(restored!.features.keys, hasLength(3));
      expect(restored.features['f3-waived']!.waiver?.at,
          '2026-08-31T01:00:00Z');
      expect(restored.inFlight?.ownerPid, 4242);
    });

    test('the store path lives under .zfa/corpus/', () {
      expect(
        store.path,
        p.join(root.path, '.zfa', 'corpus', 'progress.json'),
      );
    });
  });
}
