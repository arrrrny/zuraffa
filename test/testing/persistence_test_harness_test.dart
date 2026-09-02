// Bug #833 (tdd-persistence-test-harness) — the persistence test harness.
//
// Specs 005 (caching), 089 (offline mode), 091, 092 and all cached entities
// need real Hive CE behavior under test: TTL expiry, box corruption,
// registrar failures. This suite pins the four remediation pieces on the
// REAL hive_ce package (a direct dependency of this repo):
//
//   1. temp-box lifecycle — a fresh temp-directory box set per bootstrap,
//      closed + deleted per teardown, never shared across tests;
//   2. test clock — `advanceTime` moves the clock virtually (no real
//      sleeps), and `TtlCachePolicy` accepts the injected clock;
//   3. corruption drills — a pre-corrupted box fixture opens through the
//      recovery path (clear + re-fetch), touching nothing outside the temp
//      box;
//   4. registrar gate — init-time registration failure surfaces as a
//      deterministic `RegistrarGateError` from `bootstrap()` (a red at
//      init), never as a runtime read crash.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/cache_policies.dart';
import 'package:zuraffa/src/testing/persistence_test_harness.dart';

void main() {
  group('PersistenceTestHarness — temp-box lifecycle (bug #833 #1)', () {
    test(
      'bootstrap opens the box set in a fresh temp directory, teardown closes and deletes it',
      () async {
        final harness = PersistenceTestHarness(boxNames: ['todos']);
        expect(harness.isBootstrapped, isFalse);
        await harness.bootstrap();
        expect(harness.isBootstrapped, isTrue);
        final tempDir = harness.tempDir;
        expect(tempDir.existsSync(), isTrue);

        await harness.box('todos').put('k1', 'v1');
        expect(harness.box('todos').get('k1'), 'v1');

        await harness.teardown();
        expect(harness.isBootstrapped, isFalse);
        expect(
          tempDir.existsSync(),
          isFalse,
          reason: 'teardown must delete the per-test temp directory',
        );
      },
    );

    test(
      'lifecycle is per-test: a second bootstrap gets a DIFFERENT temp dir with EMPTY boxes',
      () async {
        final harness = PersistenceTestHarness(boxNames: ['todos']);
        await harness.bootstrap();
        final firstDir = harness.tempDir;
        await harness.box('todos').put('stale', 'leftover');
        await harness.teardown();

        await harness.bootstrap();
        final secondDir = harness.tempDir;
        expect(
          secondDir.path,
          isNot(firstDir.path),
          reason: 'temp-box lifecycle must be per-test, not shared',
        );
        expect(
          harness.box('todos').length,
          0,
          reason: 'the second test must not inherit the first test data',
        );
        expect(harness.box('todos').get('stale'), isNull);
        await harness.teardown();
      },
    );

    test(
      'bootstrap refuses a double bootstrap (shared lifecycle guard)',
      () async {
        final harness = PersistenceTestHarness(boxNames: ['todos']);
        await harness.bootstrap();
        await expectLater(harness.bootstrap(), throwsA(isA<StateError>()));
        await harness.teardown();
      },
    );

    test('teardown without bootstrap is a safe no-op', () async {
      final harness = PersistenceTestHarness(boxNames: ['todos']);
      await harness.teardown();
      expect(harness.isBootstrapped, isFalse);
    });
  });

  group('TestClock — advanceTime without real sleeps (bug #833 #2)', () {
    test(
      'advanceTime moves the clock virtually while wall-clock barely moves',
      () {
        final clock = TestClock();
        final before = clock.now;
        final wall = Stopwatch()..start();
        clock.advanceTime(const Duration(hours: 6));
        wall.stop();

        expect(clock.now.isAfter(before), isTrue);
        expect(
          clock.now.difference(before),
          const Duration(hours: 6),
          reason: 'the clock must advance exactly the requested duration',
        );
        expect(
          wall.elapsed,
          lessThan(const Duration(seconds: 1)),
          reason: 'advanceTime must never sleep for real',
        );
      },
    );

    test(
      'the clock is injectable as a DateTime source and does not leak between instances',
      () {
        final fast = TestClock();
        final slow = TestClock();
        final beforeFast = fast.now;
        fast.advanceTime(const Duration(days: 30));

        expect(
          slow.now,
          isNot(fast.now),
          reason: 'advancing one clock must not move another',
        );
        expect(fast.now.difference(beforeFast), const Duration(days: 30));
        // Usable directly as the policy's DateTime source.
        DateTime Function() source = fast.call;
        expect(source(), fast.now);
      },
    );

    test(
      'TtlCachePolicy expires virtually under the injected clock (no real sleep)',
      () async {
        final clock = TestClock();
        final store = <String, int>{};
        final policy = TtlCachePolicy(
          ttl: const Duration(hours: 6),
          getTimestamps: () async => store,
          setTimestamp: (key, ts) async => store[key] = ts,
          removeTimestamp: (key) async => store.remove(key),
          clearAll: () async => store.clear(),
          clock: clock.call,
        );

        await policy.markFresh('listing');
        expect(
          await policy.isValid('listing'),
          isTrue,
          reason: 'fresh entry must be valid before the TTL elapses',
        );

        final wall = Stopwatch()..start();
        clock.advanceTime(const Duration(hours: 7));
        wall.stop();
        expect(
          wall.elapsed,
          lessThan(const Duration(seconds: 1)),
          reason: 'TTL expiry must be asserted virtually — no real sleeps',
        );

        expect(
          await policy.isValid('listing'),
          isFalse,
          reason: 'the entry must be expired after the virtual TTL elapsed',
        );
      },
    );

    test(
      'TtlCachePolicy without a clock keeps the real-time default',
      () async {
        final store = <String, int>{};
        final policy = TtlCachePolicy(
          ttl: const Duration(hours: 6),
          getTimestamps: () async => store,
          setTimestamp: (key, ts) async => store[key] = ts,
          removeTimestamp: (key) async => store.remove(key),
          clearAll: () async => store.clear(),
        );
        await policy.markFresh('listing');
        expect(await policy.isValid('listing'), isTrue);
      },
    );
  });

  group('Corruption drills — pre-corrupted fixture + recovery (bug #833 #3)', () {
    test(
      'drill opens a pre-corrupted box and recovers it to an empty, re-fetchable box',
      () async {
        final harness = PersistenceTestHarness(boxNames: ['listings']);
        await harness.bootstrap();
        final tempDir = harness.tempDir;
        // Seed a healthy entry, release the live box, corrupt its file.
        await harness.box('listings').put('good', 'row');
        await harness.box('listings').close();
        harness.seedCorruptedBox('listings');
        final corruptFile = File(harness.boxPath('listings'));
        expect(
          corruptFile.existsSync(),
          isTrue,
          reason: 'the pre-corrupted fixture must exist inside the temp box',
        );
        expect(corruptFile.lengthSync(), greaterThan(0));

        final recovered = await harness.openWithRecovery<String>('listings');
        expect(
          recovered.length,
          0,
          reason:
              'recovery must clear the corrupted fixture (clear + re-fetch)',
        );
        expect(recovered.get('good'), isNull);
        expect(tempDir.existsSync(), isTrue);
        await harness.teardown();
      },
    );

    test('drill destroys nothing outside the temp box', () async {
      final harness = PersistenceTestHarness(boxNames: ['listings', 'prices']);
      await harness.bootstrap();
      final tempDir = harness.tempDir;

      // Sentinel OUTSIDE the temp dir + a healthy sibling box INSIDE it.
      final sentinelDir = await Directory.systemTemp.createTemp(
        'zfa_harness_sentinel_',
      );
      final sentinelFile = File('${sentinelDir.path}/precious.txt');
      await sentinelFile.writeAsString('must survive the drill');

      await harness.box('prices').put('p1', 'keep-me');
      final pricesPath = harness.boxPath('prices');
      final pricesBytesBefore = File(pricesPath).readAsBytesSync();

      // Release the drill target before corrupting it (the sibling stays
      // open — the drill must not need it).
      await harness.box('listings').close();
      harness.seedCorruptedBox('listings');
      await harness.openWithRecovery<String>('listings');

      expect(
        sentinelFile.readAsStringSync(),
        'must survive the drill',
        reason: 'the drill must not destroy data outside the temp box',
      );
      expect(sentinelDir.existsSync(), isTrue);
      expect(
        File(pricesPath).readAsBytesSync(),
        pricesBytesBefore,
        reason: 'sibling boxes in the temp set must be untouched',
      );
      expect(File(pricesPath).existsSync(), isTrue);
      expect(tempDir.existsSync(), isTrue);

      await harness.teardown();
      sentinelDir.deleteSync(recursive: true);
    });

    test(
      'drill fails deterministically when the recovery contract is violated',
      () async {
        final harness = PersistenceTestHarness(boxNames: ['listings']);
        await harness.bootstrap();
        // A box that is NOT corrupted: opening it yields the seeded row, so
        // a drill demanding an empty recovered box must fail — the drill
        // only passes over a genuine corrupted fixture.
        await harness.box('listings').put('real', 'row');
        await harness.box('listings').close();
        await expectLater(
          harness.openWithRecovery<String>('listings'),
          throwsA(isA<CorruptionDrillFailure>()),
        );
        await harness.teardown();
      },
    );

    test('seedCorruptedBox refuses to corrupt an open box', () async {
      final harness = PersistenceTestHarness(boxNames: ['listings']);
      await harness.bootstrap();
      expect(
        () => harness.seedCorruptedBox('listings'),
        throwsA(isA<StateError>()),
      );
      await harness.teardown();
    });
  });

  group('Registrar gate — deterministic init-time red (bug #833 #4)', () {
    test(
      'a registration failure surfaces from bootstrap as RegistrarGateError',
      () async {
        final harness = PersistenceTestHarness(
          boxNames: ['todos'],
          registerAdapters: () => throw StateError('duplicate typeId 42'),
        );
        await expectLater(
          harness.bootstrap(),
          throwsA(
            isA<RegistrarGateError>().having(
              (e) => e.message,
              'message',
              contains('duplicate typeId 42'),
            ),
          ),
          reason:
              'init-time registration failure must surface as a deterministic '
              'red at bootstrap, not as a runtime read crash (spec 005 US3-AC3)',
        );
        expect(harness.isBootstrapped, isFalse);
      },
    );

    test(
      'a missing expected adapter is surfaced at bootstrap, not on first read',
      () async {
        final harness = PersistenceTestHarness(
          boxNames: ['todos'],
          expectedTypeIds: {42},
        );
        await expectLater(
          harness.bootstrap(),
          throwsA(
            isA<RegistrarGateError>().having(
              (e) => e.message,
              'message',
              contains('42'),
            ),
          ),
        );
      },
    );

    test('a healthy registrar passes the gate and boxes open', () async {
      var registered = false;
      final harness = PersistenceTestHarness(
        boxNames: ['todos'],
        registerAdapters: () => registered = true,
      );
      await harness.bootstrap();
      expect(registered, isTrue);
      await harness.box('todos').put('k', 'v');
      expect(harness.box('todos').get('k'), 'v');
      await harness.teardown();
    });
  });
}
