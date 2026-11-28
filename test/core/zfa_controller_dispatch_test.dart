import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// --- Fixtures -------------------------------------------------------------

/// A v8 domain state: any member of a `@ZorphyState` hierarchy implements
/// [ZorphyStateBase]. Hand-written stand-ins keep the test focused on the
/// controller execution loop rather than on code generation.
class CounterDomain implements ZorphyStateBase {
  const CounterDomain(this.count);
  final int count;

  CounterDomain increment() => CounterDomain(count + 1);
}

class FormUi implements ZorphyStateBase {
  const FormUi(this.draft);
  final String draft;

  FormUi copyWith(String draft) => FormUi(draft);
}

/// An intent that exposes replay metadata so the controller can track its
/// canonical digest in flight.
class IncrementIntent implements ZorphyIntentBase, ZfaIntentMetadata {
  const IncrementIntent(this.by);
  final int by;

  @override
  bool get replaySafe => true;

  @override
  String get intentName => 'IncrementIntent';

  @override
  String intentDigest() => ZorphyIntentDigest.compute(intentName, {'by': by});
}

/// An intent with no replay metadata — the controller must still dispatch it,
/// just without a digest to track.
class BareIntent implements ZorphyIntentBase {
  const BareIntent();
}

/// Terminal intent a reaction chains to (no further reaction matches it).
class DoneIntent implements ZorphyIntentBase {
  const DoneIntent(this.total);
  final int total;
}

void main() {
  group('ZfaController typed dispatch', () {
    test('dispatch runs the intent and returns its result', () async {
      final controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi(''),
        runner: (intent, ctx) async {
          ctx.throwIfCancelled();
          if (intent is IncrementIntent) {
            return Result.success(intent.by);
          }
          return Result.success(0);
        },
      );

      final result = await controller.dispatch<IncrementIntent, int>(
        const IncrementIntent(3),
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(3));
    });

    test('dispatch tracks the intent digest in flight while running', () async {
      final seenInFlight = <List<String>>[];
      late final ZfaController<CounterDomain, FormUi> controller;
      controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi(''),
        runner: (intent, ctx) async {
          // Observe the in-flight set from inside the run.
          seenInFlight.add(controller.inFlightIntentDigests.toList());
          return Result.success(0);
        },
      );

      await controller.dispatch<IncrementIntent, int>(const IncrementIntent(1));

      expect(seenInFlight, hasLength(1));
      expect(
        seenInFlight.single,
        contains(const IncrementIntent(1).intentDigest()),
      );
      // Cleared once the dispatch settles.
      expect(controller.inFlightIntentDigests, isEmpty);
    });

    test(
      'dispatch propagates sourceContractId into span and baggage',
      () async {
        ZfaContext? capturedCtx;
        final controller = ZfaController<CounterDomain, FormUi>(
          initialDomain: const CounterDomain(0),
          initialUi: const FormUi(''),
          runner: (intent, ctx) async {
            capturedCtx = ctx;
            return Result.success(0);
          },
        );

        await controller.dispatch<IncrementIntent, int>(
          const IncrementIntent(1),
          sourceContractId: 'contract-42',
        );

        final ctx = capturedCtx!;
        expect(ctx.span, isNotNull);
        expect(ctx.span!.attributes['sourceContractId'], equals('contract-42'));
        expect(ctx.baggage['sourceContractId'], equals('contract-42'));
      },
    );

    test('dispatch without sourceContractId adds no span', () async {
      ZfaContext? capturedCtx;
      final root = ZfaContext.root();
      final controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi(''),
        runner: (intent, ctx) async {
          capturedCtx = ctx;
          return Result.success(0);
        },
      );

      await controller.dispatch<IncrementIntent, int>(
        const IncrementIntent(1),
        ctx: root,
      );

      // No sourceContractId → the caller's context flows through unchanged.
      expect(capturedCtx!.span, isNull);
    });

    test('patchUiState updates the uiState signal', () async {
      final controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi('start'),
        runner: (intent, ctx) async => Result.success(0),
      );

      controller.patchUiState((current) => current.copyWith('edited'));

      expect(controller.uiState.value.draft, equals('edited'));
    });

    test('owner disposal cancels active contexts', () async {
      final owner = Object();
      final gate = Completer<void>();
      ZfaContext? activeCtx;
      final controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi(''),
        owner: owner,
        runner: (intent, ctx) async {
          activeCtx = ctx;
          // Hold the dispatch open until the test releases it.
          await gate.future;
          return Result.success(0);
        },
      );

      final pending = controller.dispatch<IncrementIntent, int>(
        const IncrementIntent(1),
      );
      // Let the runner reach its await.
      await Future<void>.delayed(Duration.zero);
      expect(activeCtx, isNotNull);
      expect(activeCtx!.cancellation.isCancelled, isFalse);

      // Disposing the owner must cancel the in-flight context.
      ZfaSignal.disposeOwner(owner);
      expect(activeCtx!.cancellation.isCancelled, isTrue);

      gate.complete();
      await pending;
    });

    test('dispatch through a reaction bus chains choreography', () async {
      final bus = ZfaReactionBus();
      bus.onSuccess<IncrementIntent, int, DoneIntent>(
        reactionId: 'counter.increment -> done',
        toIntent: (_, output) => DoneIntent(output),
      );

      final seenIntents = <String>[];
      final controller = ZfaController<CounterDomain, FormUi>(
        initialDomain: const CounterDomain(0),
        initialUi: const FormUi(''),
        bus: bus,
        runner: (intent, ctx) async {
          if (intent is IncrementIntent) {
            seenIntents.add('increment:${intent.by}');
            return Result.success(intent.by);
          }
          if (intent is DoneIntent) {
            seenIntents.add('done:${intent.total}');
            return Result.success(intent.total);
          }
          return Result.success(0);
        },
      );

      final result = await controller.dispatch<IncrementIntent, int>(
        const IncrementIntent(2),
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), equals(2));
      // Initial run + one chained reaction, in order.
      expect(seenIntents, equals(['increment:2', 'done:2']));
    });
  });
}
