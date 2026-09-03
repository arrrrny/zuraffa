// Spec 069-corpus-economics — T003: corpus sharding (part 1).
//
// The per-PR corpus lane must complete ≤ 10 minutes (issue #916): the
// 120-feature corpus splits across N shard invocations
// (`zfa tdd corpus run --shard <i>/<n>`) that run CONCURRENTLY (a CI
// matrix), each driving its own deterministic feature subset. This file
// pins the sharding contract:
//
//   1. Deterministic round-robin in manifest order — the same manifest
//      + shard spec always selects the same features (plan risk:
//      "sharding must produce deterministic results").
//   2. Exact coverage: every feature lands in exactly ONE shard (no
//      gaps, no overlaps) — the union of shards equals the manifest.
//   3. Order preserved within a shard (manifest order, not hash order).
//   4. Malformed shard specs are usage errors ("2", "0/3", "3/2", "i/n").
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_sharder.dart';

void main() {
  final manifest = List.generate(
    12,
    (i) => 'feature-${(i + 1).toString().padLeft(2, '0')}',
  );

  group('CorpusSharder.shard — deterministic round-robin', () {
    test('distributes the manifest across N shards, preserving manifest '
        'order within each shard', () {
      final shards = CorpusSharder.shard(manifest, 3);
      expect(shards, hasLength(3));
      // Round-robin: shard 0 gets features 1, 4, 7, 10 (positions
      // 0, 3, 6, 9) — manifest order preserved inside the shard.
      expect(shards[0], [
        'feature-01',
        'feature-04',
        'feature-07',
        'feature-10',
      ]);
      expect(shards[1], [
        'feature-02',
        'feature-05',
        'feature-08',
        'feature-11',
      ]);
      expect(shards[2], [
        'feature-03',
        'feature-06',
        'feature-09',
        'feature-12',
      ]);
    });

    test('deterministic: the same manifest + shard count select the same '
        'features on every call', () {
      final first = CorpusSharder.shard(manifest, 4);
      final second = CorpusSharder.shard(manifest, 4);
      expect(first, equals(second));
    });

    test('exact coverage: the union of the shards equals the manifest, '
        'every feature in exactly ONE shard (no gaps, no overlaps)', () {
      for (final n in [1, 2, 3, 5, 12, 16]) {
        final shards = CorpusSharder.shard(manifest, n);
        final union = <String>{};
        for (final shard in shards) {
          for (final feature in shard) {
            expect(
              union.contains(feature),
              isFalse,
              reason: '$feature appears in two shards (n=$n)',
            );
            union.add(feature);
          }
        }
        expect(union, manifest.toSet(), reason: 'n=$n union mismatch');
        // Shard sizes differ by at most one (balanced).
        final sizes = shards.map((s) => s.length).toSet();
        expect(sizes.length <= 2, isTrue, reason: 'n=$n unbalanced: $sizes');
      }
    });

    test('more shards than features: every feature still lands in a shard '
        '(empty shards allowed, never a dropped feature)', () {
      final shards = CorpusSharder.shard(['a', 'b'], 5);
      expect(shards, hasLength(5));
      expect(shards.expand((s) => s).toSet(), {'a', 'b'});
      expect(shards[0], ['a']);
      expect(shards[1], ['b']);
      expect(shards[2], isEmpty);
      expect(shards[4], isEmpty);
    });

    test('a 120-feature corpus splits into 12-per-shard across 10 shards '
        '(the per-PR lane math behind the ≤ 10 min target)', () {
      final corpus = List.generate(
        120,
        (i) => 'spec-${(i + 1).toString().padLeft(3, '0')}',
      );
      final shards = CorpusSharder.shard(corpus, 10);
      expect(shards, hasLength(10));
      expect(shards.map((s) => s.length).toSet(), {12});
    });
  });

  group('CorpusSharder.selectShard — the --shard <i>/<n> selection', () {
    test('selects exactly the i-th round-robin shard (1-based i)', () {
      final selected = CorpusSharder.selectShard(
        ordered: manifest,
        index: 2,
        count: 3,
      );
      expect(selected, CorpusSharder.shard(manifest, 3)[1]);
    });

    test('the selection is stable across invocations (deterministic)', () {
      expect(
        CorpusSharder.selectShard(ordered: manifest, index: 1, count: 4),
        equals(
          CorpusSharder.selectShard(ordered: manifest, index: 1, count: 4),
        ),
      );
    });
  });

  group('CorpusSharder.parseShardSpec — the <i>/<n> grammar', () {
    test('parses a valid 1-based spec', () {
      expect(CorpusSharder.parseShardSpec('2/4'), (2, 4));
      expect(CorpusSharder.parseShardSpec('1/1'), (1, 1));
      expect(CorpusSharder.parseShardSpec('10/10'), (10, 10));
    });

    test('rejects malformed specs with a usage-shaped error', () {
      for (final bad in ['2', '0/3', '3/2', '4/3', 'i/n', '1/0', '-1/2', '']) {
        expect(
          () => CorpusSharder.parseShardSpec(bad),
          throwsA(isA<ShardSpecFormatException>()),
          reason: 'spec "$bad" must be rejected',
        );
      }
    });

    test('the error message names the spec and the expected shape', () {
      try {
        CorpusSharder.parseShardSpec('3/2');
        fail('unreachable');
      } on ShardSpecFormatException catch (e) {
        expect(e.message, contains('3/2'));
        expect(e.message, contains('<i>/<n>'));
      }
    });
  });
}
