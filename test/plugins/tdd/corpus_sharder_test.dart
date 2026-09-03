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
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'shardCount'),
        ),
      );
    });

    test('shardLane returns exactly one lane', () {
      final features = List.generate(7, (i) => 'f${i + 1}');
      // Lane 0 is valid (the first lane) — never refused.
      expect(
        sharder.shardLane(features: features, shardCount: 3, shardIndex: 0),
        ['f1', 'f4', 'f7'],
      );
      expect(
        sharder.shardLane(features: features, shardCount: 3, shardIndex: 2),
        ['f3', 'f6'],
      );
      // The out-of-range lane index is a NAMED ArgumentError (never a
      // raw RangeError leaking from the shard list access).
      expect(
        () =>
            sharder.shardLane(features: features, shardCount: 3, shardIndex: 3),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'shardIndex')
              .having(
                (e) => e.message,
                'message',
                contains(
                  'must be in [0, 3) (0-based; the CLI flag is 1-based)',
                ),
              ),
        ),
      );
      expect(
        () => sharder.shardLane(
          features: features,
          shardCount: 3,
          shardIndex: -1,
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'shardIndex'),
        ),
      );
      // Index BEYOND count+1 must still be the NAMED refusal, never a
      // RangeError leaking from the shard list access.
      expect(
        () =>
            sharder.shardLane(features: features, shardCount: 3, shardIndex: 4),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'shardIndex'),
        ),
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
      void expectInvalid(String raw) {
        expect(
          () => CorpusSharder.parseShardSpec(raw),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('invalid --shard "$raw"'),
            ),
          ),
        );
      }

      // The message names the expected CI matrix form + the 1-based
      // convention (the error prose is a contract: operators paste it
      // straight into CI configs).
      void expectInvalidWithForm(String raw) {
        expect(
          () => CorpusSharder.parseShardSpec(raw),
          throwsA(
            isA<FormatException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('invalid --shard "$raw"'),
                )
                // The full expected-form sentence (the error prose is
                // the operator-facing contract).
                .having(
                  (e) => e.message,
                  'message',
                  contains(
                    'expected the CI matrix form <i>/<k> such as 1/4 '
                    '(1-based lane index of the lane count).',
                  ),
                ),
          ),
        );
      }

      // The shape-mismatch errors name the expected CI matrix form.
      expectInvalidWithForm('abc');
      expectInvalidWithForm('4');
      // The range errors name the valid 1-based window.
      expectInvalid('0/4');
      expectInvalid('5/4');
      expectInvalid('1/0');
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
      // Negative feature counts / per-feature costs never divide into
      // a negative lane count — the floor is one lane.
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: -5,
          minutesPerFeature: 1,
          targetLaneMinutes: 10,
        ),
        1,
      );
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 10,
          minutesPerFeature: 0,
          targetLaneMinutes: 10,
        ),
        1,
      );
      expect(
        CorpusSharder.suggestLaneCount(
          featureCount: 10,
          minutesPerFeature: -1,
          targetLaneMinutes: 10,
        ),
        1,
      );
    });
  });
}
