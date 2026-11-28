import 'dart:async';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/cancel_token.dart' show CancelledException;
import 'package:zuraffa/src/core/context/zfa_context.dart';
import 'package:zuraffa/src/core/failure.dart';
import 'package:zuraffa/src/core/middleware/zfa_middleware.dart';
import 'package:zuraffa/src/core/reactions/zfa_reaction_bus.dart';
import 'package:zuraffa/src/core/result.dart';
import 'package:zuraffa/src/core/signals/zfa_signal.dart';
import 'package:zuraffa/src/core/usecase/usecase.dart';
import 'package:zuraffa/src/core/usecase/sync_usecase.dart';
import 'package:zuraffa/src/core/usecase/watch_usecase.dart';
import 'package:zorphy_annotation/zorphy_annotation.dart' show ZorphyIntentBase;

// --- Fixtures -------------------------------------------------------------

/// A v8 intent: any member of a `@ZorphyIntent` hierarchy implements
/// [ZorphyIntentBase]. This hand-written stand-in keeps the test focused on the
/// UseCase archetypes rather than on code generation.
class AddIntent implements ZorphyIntentBase {
  const AddIntent(this.a, this.b);
  final int a;
  final int b;
}

class BoomIntent implements ZorphyIntentBase {
  const BoomIntent();
}

/// A middleware that records its passage and transforms the success value.
class TaggingMiddleware implements ZfaMiddleware<AddIntent, int> {
  TaggingMiddleware(this.prefix);
  final String prefix;
  static final List<String> log = [];

  @override
  Future<Result<int, AppFailure>> intercept(
    AddIntent intent,
    ZfaMiddlewareContext ctx,
    NextUseCase<AddIntent, int> next,
  ) async {
    log.add('$prefix-pre');
    final res = await next(intent, ctx);
    log.add('$prefix-post');
    return res.map((v) => v);
  }
}

class AddUseCase extends UseCase<AddIntent, int> {
  AddUseCase({super.middleware});
  int calls = 0;

  @override
  Future<Result<int, AppFailure>> execute(
    AddIntent intent,
    ZfaContext ctx,
  ) async {
    calls++;
    ctx.throwIfCancelled();
    return Result.success(intent.a + intent.b);
  }
}

class CancelledUseCase extends UseCase<AddIntent, int> {
  @override
  Future<Result<int, AppFailure>> execute(
    AddIntent intent,
    ZfaContext ctx,
  ) async {
    throw const CancelledException('stop now');
  }
}

class ThrowingUseCase extends UseCase<BoomIntent, int> {
  @override
  Future<Result<int, AppFailure>> execute(
    BoomIntent intent,
    ZfaContext ctx,
  ) async {
    throw StateError('kaboom');
  }
}

class SyncAddUseCase extends SyncUseCase<AddIntent, int> {
  @override
  Result<int, AppFailure> execute(AddIntent intent, ZfaContext ctx) {
    ctx.throwIfCancelled();
    return Result.success(intent.a + intent.b);
  }
}

class SyncCancelledUseCase extends SyncUseCase<AddIntent, int> {
  @override
  Result<int, AppFailure> execute(AddIntent intent, ZfaContext ctx) {
    throw const CancelledException('sync stop');
  }
}

class SyncThrowingUseCase extends SyncUseCase<BoomIntent, int> {
  @override
  Result<int, AppFailure> execute(BoomIntent intent, ZfaContext ctx) {
    throw StateError('sync kaboom');
  }
}

class WatchAddUseCase extends WatchUseCase<AddIntent, int> {
  WatchAddUseCase({super.middleware});
  int refreshes = 0;

  @override
  Result<int, AppFailure> read(AddIntent intent, ZfaContext ctx) {
    return Result.success(intent.a + intent.b);
  }

  @override
  Future<Result<int, AppFailure>> execute(
    AddIntent intent,
    ZfaContext ctx,
  ) async {
    refreshes++;
    return Result.success(intent.a + intent.b + refreshes);
  }
}

void main() {
  group('UseCase', () {
    test(
      'call runs the intent through the middleware chain and succeeds',
      () async {
        TaggingMiddleware.log.clear();
        final uc = AddUseCase(middleware: [TaggingMiddleware('outer')]);
        final ctx = ZfaContext.root();

        final result = await uc.call(const AddIntent(2, 3), ctx);

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull(), 5);
        expect(uc.calls, 1);
        expect(TaggingMiddleware.log, ['outer-pre', 'outer-post']);
      },
    );

    test(
      'call translates CancelledException into a cancelled AppFailure',
      () async {
        final uc = CancelledUseCase();
        final result = await uc.call(const AddIntent(1, 1), ZfaContext.root());

        expect(result.isFailure, isTrue);
        final failure = result.getFailureOrNull()!;
        expect(failure, isA<CancelledFailure>());
      },
    );

    test('call wraps an unexpected throw into a failure', () async {
      final uc = ThrowingUseCase();
      final result = await uc.call(const BoomIntent(), ZfaContext.root());

      expect(result.isFailure, isTrue);
      expect(result.getFailureOrNull(), isNotNull);
    });

    test('a UseCase is usable as a ZfaReactionBus runner', () async {
      final bus = ZfaReactionBus();
      final uc = AddUseCase();

      final result = await bus.run(
        const AddIntent(4, 6),
        runner: (intent, ctx) async => uc.call(intent as AddIntent, ctx),
        context: ZfaContext.root(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), 10);
    });
  });

  group('SyncUseCase', () {
    test('call returns a synchronous success', () {
      final uc = SyncAddUseCase();
      final result = uc.call(const AddIntent(7, 8), ZfaContext.root());

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), 15);
    });

    test('call translates CancelledException into a cancelled AppFailure', () {
      final uc = SyncCancelledUseCase();
      final result = uc.call(const AddIntent(0, 0), ZfaContext.root());

      expect(result.isFailure, isTrue);
      expect(result.getFailureOrNull(), isA<CancelledFailure>());
    });

    test('call wraps an unexpected throw into a failure', () {
      final uc = SyncThrowingUseCase();
      final result = uc.call(const BoomIntent(), ZfaContext.root());

      expect(result.isFailure, isTrue);
      expect(result.getFailureOrNull(), isNotNull);
    });
  });

  group('WatchUseCase', () {
    test('watch seeds an owner-bound signal with the synchronous read', () {
      final uc = WatchAddUseCase();
      final owner = Object();
      final ctx = ZfaContext.root();

      final signal = uc.watch(const AddIntent(10, 5), ctx, owner: owner);

      expect(signal.value.isSuccess, isTrue);
      expect(signal.value.getOrNull(), 15);
      // The async refresh has not necessarily run yet; the seed is synchronous.
      expect(uc.refreshes, 0);
    });

    test(
      'watch refreshes the signal when the async execute completes',
      () async {
        final uc = WatchAddUseCase();
        final owner = Object();
        final ctx = ZfaContext.root();

        final signal = uc.watch(const AddIntent(1, 1), ctx, owner: owner);
        // Let the scheduled refresh run.
        await Future<void>.delayed(Duration.zero);

        expect(uc.refreshes, 1);
        expect(signal.value.getOrNull(), 3); // 1 + 1 + 1 refresh
      },
    );

    test('the signal is disposed when its owner is disposed', () {
      final uc = WatchAddUseCase();
      final owner = Object();
      final ctx = ZfaContext.root();

      final signal = uc.watch(const AddIntent(1, 1), ctx, owner: owner);
      expect(signal.isDisposed, isFalse);

      ZfaSignal.disposeOwner(owner);
      expect(signal.isDisposed, isTrue);
    });
  });
}
