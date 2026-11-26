import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

// --- Choreography fixtures: ImportOrder -> CheckPrice -> SendNotification ---

class ImportOrderIntent {
  const ImportOrderIntent(this.orderId);
  final String orderId;
}

class Order {
  const Order(this.orderId, this.productId);
  final String orderId;
  final String productId;
}

class CheckPriceIntent {
  const CheckPriceIntent(this.productId);
  final String productId;
}

class PriceCheck {
  const PriceCheck(this.productId, this.price);
  final String productId;
  final double price;
}

class SendNotificationIntent {
  const SendNotificationIntent(this.productId, this.price);
  final String productId;
  final double price;
}

class NotificationSent {
  const NotificationSent(this.productId);
  final String productId;
}

// --- Circular-loop fixtures ---

class LoopIntent {
  const LoopIntent(this.n);
  final int n;
}

class LoopOutput {
  const LoopOutput(this.n);
  final int n;
}

// --- Failure-recovery fixtures ---

class FailingIntent {
  const FailingIntent();
}

class RecoveryIntent {
  const RecoveryIntent();
}

void main() {
  group('ZfaReactionBus chained choreography', () {
    test(
      'chains ImportOrder -> CheckPrice -> SendNotification in order',
      () async {
        final bus = ZfaReactionBus();
        bus.onSuccess<ImportOrderIntent, Order, CheckPriceIntent>(
          reactionId: 'order.import -> price.check',
          toIntent: (intent, order) => CheckPriceIntent(order.productId),
        );
        bus.onSuccess<CheckPriceIntent, PriceCheck, SendNotificationIntent>(
          reactionId: 'price.check -> notification.send',
          toIntent: (intent, check) =>
              SendNotificationIntent(check.productId, check.price),
        );

        final executed = <Object>[];
        final depths = <int>[];
        final contexts = <ZfaContext>[];

        Future<Result<Object?, AppFailure>> runner(
          Object intent,
          ZfaContext ctx,
        ) async {
          ctx.throwIfCancelled();
          executed.add(intent);
          depths.add(ctx.cascadeDepth);
          contexts.add(ctx);
          if (intent is ImportOrderIntent) {
            return Result.success(Order(intent.orderId, 'product-1'));
          }
          if (intent is CheckPriceIntent) {
            return Result.success(PriceCheck(intent.productId, 9.99));
          }
          if (intent is SendNotificationIntent) {
            return Result.success(NotificationSent(intent.productId));
          }
          throw StateError('unexpected intent: $intent');
        }

        final root = ZfaContext.root();
        final result = await bus.run(
          const ImportOrderIntent('order-1'),
          runner: runner,
          context: root,
        );

        expect(result.isSuccess, isTrue);
        expect(executed.map((e) => e.runtimeType).toList(), <Type>[
          ImportOrderIntent,
          CheckPriceIntent,
          SendNotificationIntent,
        ]);
        // cascadeDepth increments by one per reaction hop, starting at the root.
        expect(depths, <int>[0, 1, 2]);
        // The causal span chain (traceId lineage) is preserved across hops.
        expect(contexts[0].span, isNull); // root carries no span
        expect(contexts[1].span?.operation, 'order.import -> price.check');
        expect(
          contexts[2].span?.parent,
          same(contexts[1].span),
          reason: 'each child span links back to its causal parent',
        );
        // Cancellation tokens cascade: every hop is a child of the root token.
        expect(contexts[1].cancellation, isNot(same(root.cancellation)));
      },
    );

    test(
      'propagates cancellation from the root context to every hop',
      () async {
        final bus = ZfaReactionBus();
        bus.onSuccess<ImportOrderIntent, Order, CheckPriceIntent>(
          reactionId: 'order.import -> price.check',
          toIntent: (_, order) => CheckPriceIntent(order.productId),
        );

        final root = ZfaContext.root();
        final cancelledAtHop = <bool>[];

        Future<Result<Object?, AppFailure>> runner(
          Object intent,
          ZfaContext ctx,
        ) async {
          cancelledAtHop.add(ctx.cancellation.isCancelled);
          // Cancel the root on the first hop; the next hop must observe it.
          if (intent is ImportOrderIntent) {
            root.cancellation.cancel('stop');
            return Result.success(Order(intent.orderId, 'product-1'));
          }
          return Result.success(const PriceCheck('product-1', 1.0));
        }

        final result = await bus.run(
          const ImportOrderIntent('order-1'),
          runner: runner,
          context: root,
        );

        expect(result.isSuccess, isTrue);
        // First hop runs before the cancel; the child hop is born into a
        // cancelled lineage and observes the cascaded cancellation.
        expect(cancelledAtHop, <bool>[false, true]);
      },
    );

    test(
      'a reaction only fires for its registered input/output types',
      () async {
        final bus = ZfaReactionBus();
        bus.onSuccess<ImportOrderIntent, Order, CheckPriceIntent>(
          reactionId: 'order.import -> price.check',
          toIntent: (_, order) => CheckPriceIntent(order.productId),
        );

        var calls = 0;
        Future<Result<Object?, AppFailure>> runner(
          Object intent,
          ZfaContext ctx,
        ) async {
          calls++;
          // Output type (PriceCheck) does not match the registered O (Order).
          return Result.success(const PriceCheck('product-1', 1.0));
        }

        final result = await bus.run(
          const ImportOrderIntent('order-1'),
          runner: runner,
          context: ZfaContext.root(),
        );

        expect(result.isSuccess, isTrue);
        expect(
          calls,
          1,
          reason: 'no reaction matched, the chain stops at one hop',
        );
      },
    );
  });

  group('ZfaReactionBus cascade loop guard', () {
    test('halts a circular reaction loop at maxCascadeDepth', () async {
      final bus = ZfaReactionBus(maxCascadeDepth: 8);
      bus.onSuccess<LoopIntent, LoopOutput, LoopIntent>(
        reactionId: 'loop.self',
        toIntent: (_, output) => LoopIntent(output.n + 1),
      );

      var calls = 0;
      Future<Result<Object?, AppFailure>> runner(
        Object intent,
        ZfaContext ctx,
      ) async {
        calls++;
        return Result.success(LoopOutput((intent as LoopIntent).n));
      }

      final result = await bus.run(
        const LoopIntent(0),
        runner: runner,
        context: ZfaContext.root(),
      );

      expect(result.isFailure, isTrue);
      final failure = result.getFailureOrNull();
      expect(failure, isA<PolicyDeniedFailure>());
      expect((failure as PolicyDeniedFailure).policyRule, 'maxCascadeDepth');
      // Depth 0..8 run (9 hops); the 9th hop's child would be depth 9 > 8.
      expect(calls, bus.maxCascadeDepth + 1);
    });
  });

  group('ZfaReactionBus failure recovery', () {
    test('an onFailure reaction maps a failure to a recovery intent', () async {
      final bus = ZfaReactionBus();
      bus.onFailure<FailingIntent, RecoveryIntent>(
        reactionId: 'failing -> recover',
        toIntent: (_, _) => const RecoveryIntent(),
      );

      final executed = <Object>[];
      Future<Result<Object?, AppFailure>> runner(
        Object intent,
        ZfaContext ctx,
      ) async {
        executed.add(intent);
        if (intent is FailingIntent) {
          return Result.failure(AppFailure.unknown('boom'));
        }
        if (intent is RecoveryIntent) {
          return Result.success('recovered');
        }
        throw StateError('unexpected intent: $intent');
      }

      final result = await bus.run(
        const FailingIntent(),
        runner: runner,
        context: ZfaContext.root(),
      );

      expect(result.isSuccess, isTrue);
      expect(executed.map((e) => e.runtimeType).toList(), <Type>[
        FailingIntent,
        RecoveryIntent,
      ]);
    });
  });

  group('ZfaReactionBus runner failure channel', () {
    test(
      'cancellation thrown by the runner is returned as a Result.failure',
      () async {
        final bus = ZfaReactionBus();
        final root = ZfaContext.root();

        Future<Result<Object?, AppFailure>> runner(
          Object intent,
          ZfaContext ctx,
        ) async {
          root.cancellation.cancel('halt');
          ctx.throwIfCancelled(); // idiomatic cancellation point
          return Result.success('unreachable');
        }

        final result = await bus.run(
          const ImportOrderIntent('order-1'),
          runner: runner,
          context: root,
        );

        expect(
          result.isFailure,
          isTrue,
          reason: 'a cancelled cascade must not throw out of run()',
        );
        expect(result.getFailureOrNull(), isA<CancellationFailure>());
      },
    );

    test('rolls each hop cost up into the root ledger', () async {
      final bus = ZfaReactionBus();
      bus.onSuccess<ImportOrderIntent, Order, CheckPriceIntent>(
        reactionId: 'order.import -> price.check',
        toIntent: (_, order) => CheckPriceIntent(order.productId),
      );

      Future<Result<Object?, AppFailure>> runner(
        Object intent,
        ZfaContext ctx,
      ) async {
        ctx.cost.record(inputTokens: 10, outputTokens: 5, cost: 0.25);
        if (intent is ImportOrderIntent) {
          return Result.success(Order(intent.orderId, 'product-1'));
        }
        return Result.success(const PriceCheck('product-1', 1.0));
      }

      final root = ZfaContext.root();
      await bus.run(
        const ImportOrderIntent('order-1'),
        runner: runner,
        context: root,
      );

      // Two hops, each spending (10 in / 5 out / 0.25), rolled into the root.
      expect(root.cost.inputTokens, 20);
      expect(root.cost.outputTokens, 10);
      expect(root.cost.totalTokens, 30);
      expect(root.cost.cost, closeTo(0.5, 1e-9));
    });
  });
}
