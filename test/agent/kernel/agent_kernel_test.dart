import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/agent/kernel/agent_kernel.dart';
import 'package:zuraffa/src/agent/kernel/resource_handle.dart';

void main() {
  group('AgentKernel coalescing (FR-001, FR-002)', () {
    test(
      '50 identical concurrent missions → exactly 1 executes (SC-001)',
      () async {
        var execCount = 0;
        final kernel = AgentKernel(
          executor: (mission, group, cancelToken) async {
            execCount++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            group.emit(MissionEventPartial(mission.id, 'p1'));
            return OutcomeCompleted('result-${mission.callerId}');
          },
        );

        final key = MissionKey(
          sparkType: 'product_scan',
          normalizedValue: 'sku-1',
          country: 'US',
          strategyVariant: 'default',
        );

        final futures = List.generate(50, (i) {
          return kernel.submit(
            Mission(
              id: 'm$i',
              key: key,
              callerId: 'c$i',
            ),
          );
        });

        final outcomes = await Future.wait(futures);

        expect(execCount, equals(1), reason: 'exactly one mission executed');
        expect(outcomes.length, equals(50));
        expect(outcomes.every((o) => o is OutcomeCompleted), isTrue);
      },
    );

    test('differing strategy variant → no coalescing', () async {
      var execCount = 0;
      final kernel = AgentKernel(
        executor: (mission, group, cancelToken) async {
          execCount++;
          return OutcomeCompleted(null);
        },
      );

      final keyA = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      final keyB = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'aggressive',
      );

      await Future.wait([
        kernel.submit(Mission(id: 'a', key: keyA, callerId: 'ca')),
        kernel.submit(Mission(id: 'b', key: keyB, callerId: 'cb')),
      ]);

      expect(execCount, equals(2));
    });
  });

  group('AgentKernel introspection (FR-008)', () {
    test('reports active missions and subscriber counts', () async {
      final completer = Completer<MissionOutcome>();
      final kernel = AgentKernel(
        executor: (mission, group, cancelToken) => completer.future,
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );

      // Submit three coalesced missions — second and third attach to first.
      final f1 = kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final f2 = kernel.submit(Mission(id: 'm2', key: key, callerId: 'c2'));
      final f3 = kernel.submit(Mission(id: 'm3', key: key, callerId: 'c3'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final snap = kernel.introspect();
      expect(snap.activeMissions, hasLength(1));
      expect(snap.activeMissions.values.first.subscriberCount, equals(3));
      expect(snap.waitingSubscribers[key.canonical], equals(3));

      completer.complete(const OutcomeCompleted(null));
      await Future.wait([f1, f2, f3]);

      final snap2 = kernel.introspect();
      expect(snap2.activeMissions, isEmpty);
    });

    test('coalescing window is reported', () {
      final kernel = AgentKernel(
        config: const KernelConfig(
          coalescingWindow: Duration(milliseconds: 75),
        ),
        executor: (m, g, t) async => const OutcomeCompleted(null),
      );
      expect(
        kernel.introspect().coalescingWindow,
        equals(const Duration(milliseconds: 75)),
      );
    });
  });

  group('AgentKernel cancellation (FR-003, FR-004, FR-005, FR-006)', () {
    test('mid-exec cancel salvages partials as cancelled_partial', () async {
      final kernel = AgentKernel(
        executor: (mission, group, cancelToken) async {
          // Register a fake resource handle.
          final handle = FakeResourceHandle('webview-1');
          group.registerHandle(handle);
          group.emit(MissionEventPartial(mission.id, 'partial-1'));

          // Wait until cancelled (or 5s safety timeout).
          await cancelToken.onSettled
              .timeout(const Duration(seconds: 5), onTimeout: () {});

          expect(handle.wasDisposed, isTrue,
              reason: 'FR-004: grace period disposed the handle');
          return const OutcomeCompleted(null);
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      final f = kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final outcome = await kernel.cancel('m1');
      expect(outcome, isA<OutcomeCancelledPartial>());
      expect((outcome as OutcomeCancelledPartial).partials,
          contains('partial-1'));
      expect(outcome.label, equals('cancelled_partial'));

      // Wait for the mission future to complete (it'll get the salvaged outcome).
      final missionOutcome = await f;
      expect(missionOutcome, isA<OutcomeCancelledPartial>());
    });

    test('post-cancellation zero-leak assertion (FR-006)', () async {
      final kernel = AgentKernel(
        config: const KernelConfig(
          cancellationGracePeriod: Duration(milliseconds: 50),
        ),
        executor: (mission, group, cancelToken) async {
          final h1 = FakeResourceHandle('h1');
          final h2 = FakeResourceHandle('h2');
          group.registerHandle(h1);
          group.registerHandle(h2);
          await cancelToken.onSettled;
          return const OutcomeCompleted(null);
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );
      final f = kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await kernel.cancel('m1');
      await f;

      // After cancellation, no active groups remain.
      expect(kernel.activeGroups, isEmpty);
    });

    test('original cancel does NOT cancel subscribers (FR-003)',
        () async {
      // Subscriber scenario: original cancels, but a second subscriber
      // that joined receives the salvaged outcome.
      final kernel = AgentKernel(
        executor: (mission, group, cancelToken) async {
          group.emit(MissionEventPartial(mission.id, 'p-shared'));
          await cancelToken.onSettled
              .timeout(const Duration(seconds: 5), onTimeout: () {});
          return const OutcomeCompleted(null);
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );

      final originalFuture =
          kernel.submit(Mission(id: 'orig', key: key, callerId: 'orig'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Subscriber joins — should receive the partial event.
      final subscriberFuture =
          kernel.submit(Mission(id: 'sub1', key: key, callerId: 'sub1'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Original cancels.
      final cancelOutcome = await kernel.cancel('orig');

      // The cancel outcome is cancelled_partial (the salvaged result).
      expect(cancelOutcome, isA<OutcomeCancelledPartial>());

      // The subscriber should also receive a terminal outcome (same salvaged
      // outcome, since the group completed).
      final subOutcome = await subscriberFuture;
      expect(subOutcome, isA<OutcomeCancelledPartial>());

      // Original's future also completes.
      final origOutcome = await originalFuture;
      expect(origOutcome, isA<OutcomeCancelledPartial>());
    });
  });

  group('AgentKernel idempotency (FR-007)', () {
    test('re-submit within TTL → cached outcome (SC-004a)', () async {
      var execCount = 0;
      final kernel = AgentKernel(
        config: const KernelConfig(
          idempotencyTtl: Duration(seconds: 30),
          idempotencyEnabled: true,
        ),
        executor: (mission, group, cancelToken) async {
          execCount++;
          return OutcomeCompleted('fresh-${mission.callerId}');
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );

      final r1 = await kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      expect(r1, isA<OutcomeCompleted>());
      expect((r1 as OutcomeCompleted).result, equals('fresh-c1'));

      final r2 = await kernel.submit(Mission(id: 'm2', key: key, callerId: 'c2'));
      expect(r2, isA<OutcomeCachedServed>(),
          reason: 'second submission served cached');
      expect(execCount, equals(1));
    });

    test('after TTL expiry → fresh execution (SC-004b)', () async {
      var execCount = 0;
      final kernel = AgentKernel(
        config: const KernelConfig(
          idempotencyTtl: Duration(milliseconds: 50),
          idempotencyEnabled: true,
        ),
        executor: (mission, group, cancelToken) async {
          execCount++;
          return OutcomeCompleted('fresh-${mission.callerId}');
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );

      await kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await kernel.submit(Mission(id: 'm2', key: key, callerId: 'c2'));
      expect(execCount, equals(2));
    });

    test('disabled → always fresh', () async {
      var execCount = 0;
      final kernel = AgentKernel(
        config: const KernelConfig(idempotencyEnabled: false),
        executor: (mission, group, cancelToken) async {
          execCount++;
          return OutcomeCompleted(null);
        },
      );

      final key = MissionKey(
        sparkType: 's',
        normalizedValue: 'v',
        country: 'US',
        strategyVariant: 'default',
      );

      await kernel.submit(Mission(id: 'm1', key: key, callerId: 'c1'));
      await kernel.submit(Mission(id: 'm2', key: key, callerId: 'c2'));
      expect(execCount, equals(2));
    });
  });

  group('AgentKernel mixed-load stability (SC-003)', () {
    test('200 mixed missions (80% dup) — no deadlock, bounded by unique keys',
        () async {
      var execCount = 0;
      final kernel = AgentKernel(
        executor: (mission, group, cancelToken) async {
          execCount++;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          return OutcomeCompleted('done-${mission.id}');
        },
      );

      // 200 missions: 80% share one of 40 duplicate keys; 20% have unique keys.
      final dupKeys = List.generate(40, (i) => MissionKey(
        sparkType: 's',
        normalizedValue: 'dup-$i',
        country: 'US',
        strategyVariant: 'default',
      ));
      final uniqKeys = List.generate(40, (i) => MissionKey(
        sparkType: 's',
        normalizedValue: 'uniq-$i',
        country: 'US',
        strategyVariant: 'default',
      ));

      final missions = <Mission>[];
      for (var i = 0; i < 160; i++) {
        missions.add(Mission(
          id: 'dup-$i',
          key: dupKeys[i % 40],
          callerId: 'caller-$i',
        ));
      }
      for (var i = 0; i < 40; i++) {
        missions.add(Mission(
          id: 'uniq-$i',
          key: uniqKeys[i],
          callerId: 'caller-u$i',
        ));
      }

      // Shuffle so duplicates interleave with uniques.
      missions.shuffle();

      final outcomes = await Future.wait(
        missions.map((m) => kernel.submit(m)),
      );

      expect(outcomes.length, equals(200));
      // Exactly 40 dup executions + 40 uniq executions = 80.
      expect(execCount, equals(80));
      expect(kernel.activeGroups, isEmpty);
    });
  });
}
