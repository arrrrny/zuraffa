/// Spec 069-corpus-economics, T003 — the corpus sharder unit contract:
/// deterministic round-robin feature distribution (spec 069 FR-009,
/// issue #916: per-PR corpus lane ≤ 10 min via sharding).
library;

import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/corpus_sharder.dart';

void main() {
  const sharder = CorpusSharder();

  group('shard distribution', () {
    test('round-robin: shard i gets features i, i+k, i+2k, ...', () {
      final features = List.generate(10, (i) => 'f${i + 1}');
      final shards = sharder.shard(features: features, shardCount: 3);
      expect(shards.length, 3);
      expect(shards[0], ['f1', 'f4', 'f7', 'f10']);
      expect(shards[1], ['f2', 'f5', 'f8']);
      expect(shards[2], ['f3', 'f6', 'f9']);
    });

    test(
      'the union of all shards IS the full list; intersections are empty',
      () {
        final features = List.generate(9, (i) => 'spec-${i + 1}');
        final shards = sharder.shard(features: features, shardCount: 4);
        final union = shards.expand((s) => s).toList();
        expect(union.length, features.length);
        expect(union.toSet(), features.toSet());
        for (var i = 0; i < shards.length; i++) {
          for (var j = i + 1; j < shards.length; j++) {
            expect(
              shards[i].toSet().intersection(shards[j].toSet()),
              isEmpty,
              reason: 'shards $i and $j overlap',
            );
          }
        }
      },
    );

    test(
      'deterministic: the same list produces the same shards every time',
      () {
        final features = ['b-feature', 'a-feature', 'c-feature', 'z-feature'];
        final first = sharder.shard(features: features, shardCount: 2);
        final second = sharder.shard(features: features, shardCount: 2);
        expect(first, equals(second));
        // The GIVEN order is preserved (never re-sorted — the corpus's
        // own topological order is the drive order).
        expect(first[0], ['b-feature', 'c-feature']);
        expect(first[1], ['a-feature', 'z-feature']);
      },
    );

    test('shard count > feature count yields trailing empty shards', () {
      final shards = sharder.shard(features: ['only'], shardCount: 3);
      expect(shards, [
        ['only'],
        isEmpty,
        isEmpty,
      ]);
    });

    test('shard count < 1 is refused (never silently one big shard)', () {
      expect(
        () => sharder.shard(features: ['a'], shardCount: 0),
        throwsArgumentError,
      );
    });

    test('shardLane returns exactly one lane', () {
      final features = List.generate(7, (i) => 'f${i + 1}');
      expect(
        sharder.shardLane(features: features, shardCount: 3, shardIndex: 2),
        ['f3', 'f6'],
      );
      expect(
        () =>
            sharder.shardLane(features: features, shardCount: 3, shardIndex: 3),
        throwsArgumentError,
      );
    });
  });

  group('parseShardSpec (the --shard <i>/<k> CLI value)', () {
    test('parses the CI matrix form', () {
      expect(CorpusSharder.parseShardSpec('1/4'), (1, 4));
      expect(CorpusSharder.parseShardSpec(' 2 / 8 '), (2, 8));
    });

    test('null/empty passes through (unsharded lane)', () {
      expect(CorpusSharder.parseShardSpec(null), isNull);
      expect(CorpusSharder.parseShardSpec(''), isNull);
    });

    test('malformed values are REFUSED, never silently unsharded', () {
      expect(() => CorpusSharder.parseShardSpec('abc'), throwsFormatException);
      expect(() => CorpusSharder.parseShardSpec('4'), throwsFormatException);
      expect(() => CorpusSharder.parseShardSpec('0/4'), throwsFormatException);
      expect(() => CorpusSharder.parseShardSpec('5/4'), throwsFormatException);
      expect(() => CorpusSharder.parseShardSpec('1/0'), throwsFormatException);
    });
  });

  group('suggestLaneCount (the lane budget helper)', () {
    test('the lane count covers the feature count within the target', () {
      // 120 features, 1 min/feature, 10 min target -> 12 lanes.
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 120,
          minutesPerFeature: 1,
          targetLaneMinutes: 10,
        ),
        12,
      );
      // 120 features at 2 min each within 30 min -> 8 lanes.
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 120,
          minutesPerFeature: 2,
          targetLaneMinutes: 30,
        ),
        8,
      );
    });

    test('never suggests more lanes than features', () {
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 3,
          minutesPerFeature: 10,
          targetLaneMinutes: 1,
        ),
        3,
      );
    });

    test('degenerate inputs stay at one lane', () {
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 0,
          minutesPerFeature: 1,
          targetLaneMinutes: 10,
        ),
        1,
      );
    });
  });
}
