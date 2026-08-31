// Tests for CorpusFeatureProgress and CorpusProgress models (spec 051).
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_feature_progress.dart';

void main() {
  group('CorpusFeatureProgress', () {
    test('toJson and fromJson round-trip preserves all fields', () {
      final p = CorpusFeatureProgress(
        name: '001-app-bootstrap',
        state: CorpusFeatureState.done,
        gateOutcome: 'PASS',
        waived: WaiverRecord(
          reason: 'mutation tool unavailable',
          actor: 'maintainer',
          when: '2026-08-31T12:00:00Z',
        ),
      );
      final json = p.toJson();
      final p2 = CorpusFeatureProgress.fromJson(p.name, json);
      expect(p2.name, '001-app-bootstrap');
      expect(p2.state, CorpusFeatureState.done);
      expect(p2.gateOutcome, 'PASS');
      expect(p2.waived?.reason, 'mutation tool unavailable');
      expect(p2.waived?.actor, 'maintainer');
    });

    test('defaults to pending state with no gate or waiver', () {
      const p = CorpusFeatureProgress(name: 'test');
      expect(p.state, CorpusFeatureState.pending);
      expect(p.gateOutcome, isNull);
      expect(p.waived, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      const p = CorpusFeatureProgress(
        name: 'test',
        state: CorpusFeatureState.driving,
        gateOutcome: 'PASS',
      );
      final p2 = p.copyWith(state: CorpusFeatureState.done);
      expect(p2.state, CorpusFeatureState.done);
      expect(p2.gateOutcome, 'PASS');
      expect(p2.name, 'test');
    });
  });

  group('CorpusProgress', () {
    test('toJson and fromJson round-trip', () {
      final progress = CorpusProgress(
        features: {
          '001-ready': const CorpusFeatureProgress(
            name: '001-ready',
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ),
          '002-pending': const CorpusFeatureProgress(name: '002-pending'),
        },
        inFlight: true,
        ownerPid: 12345,
        startedAt: '2026-08-31T12:00:00Z',
      );
      final json = progress.toJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final progress2 = CorpusProgress.fromJson(decoded);
      expect(progress2.features.length, 2);
      expect(progress2.features['001-ready']?.state, CorpusFeatureState.done);
      expect(progress2.features['002-pending']?.state, CorpusFeatureState.pending);
      expect(progress2.inFlight, true);
      expect(progress2.ownerPid, 12345);
      expect(progress2.startedAt, '2026-08-31T12:00:00Z');
    });

    test('empty progress has no features', () {
      final progress = CorpusProgress();
      expect(progress.features, isEmpty);
      expect(progress.inFlight, false);
    });
  });
}
