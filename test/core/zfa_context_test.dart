import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('CancellationToken', () {
    test('starts uncancelled with no reason', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
      expect(token.isCancellationRequested, isFalse);
      expect(token.reason, isNull);
    });

    test('cancel flips the flag and records the reason', () {
      final token = CancellationToken();
      token.cancel('shutdown');
      expect(token.isCancelled, isTrue);
      expect(token.isCancellationRequested, isTrue);
      expect(token.reason, equals('shutdown'));
    });

    test('cancel is idempotent and keeps the first reason', () {
      final token = CancellationToken();
      token.cancel('first');
      token.cancel('second');
      expect(token.reason, equals('first'));
    });

    test('throwIfCancelled throws once cancelled', () {
      final token = CancellationToken();
      expect(token.throwIfCancelled, returnsNormally);
      token.cancel('boom');
      expect(
        token.throwIfCancelled,
        throwsA(
          isA<CancellationTokenException>().having(
            (e) => e.reason,
            'reason',
            'boom',
          ),
        ),
      );
    });

    test('cascading cancellation reaches children', () {
      final parent = CancellationToken();
      final child = parent.child();
      final grandchild = child.child();
      expect(child.isCancelled, isFalse);
      parent.cancel('root');
      expect(child.isCancelled, isTrue);
      expect(grandchild.isCancelled, isTrue);
      expect(grandchild.reason, equals('root'));
    });

    test('a child created after the parent is cancelled is born cancelled', () {
      final parent = CancellationToken();
      parent.cancel('early');
      final late = parent.child();
      expect(late.isCancelled, isTrue);
      expect(late.reason, equals('early'));
    });

    test('system token never cancels (background safe)', () {
      final token = CancellationToken.system();
      token.cancel('nope');
      expect(token.isCancelled, isFalse);
      expect(token.throwIfCancelled, returnsNormally);
    });
  });

  group('Deadline', () {
    test('after() produces a future expiry that is not yet expired', () {
      final deadline = Deadline.after(const Duration(seconds: 30));
      expect(deadline.isExpired, isFalse);
      expect(deadline.remaining.inSeconds, greaterThan(0));
    });

    test('a past deadline is expired', () {
      final deadline = Deadline(
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      expect(deadline.isExpired, isTrue);
    });
  });

  group('ZfaCostLedger', () {
    test('starts empty', () {
      final ledger = ZfaCostLedger();
      expect(ledger.isEmpty, isTrue);
      expect(ledger.inputTokens, 0);
      expect(ledger.outputTokens, 0);
      expect(ledger.cost, 0.0);
    });

    test('records token and cost usage cumulatively', () {
      final ledger = ZfaCostLedger();
      ledger.record(inputTokens: 10, outputTokens: 5, cost: 0.01);
      ledger.record(inputTokens: 3, outputTokens: 2, cost: 0.02);
      expect(ledger.inputTokens, 13);
      expect(ledger.outputTokens, 7);
      expect(ledger.cost, closeTo(0.03, 1e-9));
      expect(ledger.isEmpty, isFalse);
    });

    test('snapshot is immutable and detached from later writes', () {
      final ledger = ZfaCostLedger();
      ledger.record(inputTokens: 4, outputTokens: 6, cost: 0.5);
      final snap = ledger.snapshot;
      ledger.record(inputTokens: 100, cost: 9.0);
      expect(snap.inputTokens, 4);
      expect(snap.outputTokens, 6);
      expect(snap.cost, 0.5);
      expect(snap.totalTokens, 10);
    });

    test(
      'absorb rolls a child ledger into the parent (self-counting rollup)',
      () {
        final parent = ZfaCostLedger();
        final child = ZfaCostLedger();
        parent.record(inputTokens: 5, outputTokens: 5, cost: 0.1);
        child.record(inputTokens: 2, outputTokens: 3, cost: 0.4);
        parent.absorb(child);
        expect(parent.inputTokens, 7);
        expect(parent.outputTokens, 8);
        expect(parent.cost, closeTo(0.5, 1e-9));
      },
    );
  });

  group('TelemetrySpan', () {
    test('records operation, attributes and duration', () {
      final span = TelemetrySpan(
        operation: 'repo.load',
        attributes: const {'k': 'v'},
      );
      expect(span.operation, equals('repo.load'));
      expect(span.attributes['k'], equals('v'));
      expect(span.isEnded, isFalse);
      span.setAttribute('extra', 'yes');
      expect(span.attributes['extra'], equals('yes'));
      span.end();
      expect(span.isEnded, isTrue);
      expect(span.duration, isNotNull);
    });

    test('end is idempotent', () {
      final span = TelemetrySpan(operation: 'op');
      span.end();
      final first = span.duration;
      span.end();
      expect(span.duration, equals(first));
    });

    test('child span links to its parent (causal chain)', () {
      final parent = TelemetrySpan(operation: 'parent');
      final child = TelemetrySpan(operation: 'child', parent: parent);
      expect(child.parent, same(parent));
      expect(parent.children, contains(child));
    });
  });

  group('ZfaContext.root', () {
    test('root carries cascadeDepth 0 and a live cancellation token', () {
      final ctx = ZfaContext.root();
      expect(ctx.cascadeDepth, 0);
      expect(ctx.cancellation.isCancelled, isFalse);
      expect(ctx.span, isNull);
      expect(ctx.isBackground, isFalse);
    });

    test('root accepts an external cancellation token and deadline', () {
      final token = CancellationToken();
      final deadline = Deadline.after(const Duration(minutes: 1));
      final ctx = ZfaContext.root(cancellation: token, deadline: deadline);
      expect(ctx.cancellation, same(token));
      expect(ctx.deadline, same(deadline));
    });
  });

  group('ZfaContext.background', () {
    test('is a non-cancelling, immutable system context', () {
      final bg = ZfaContext.background;
      expect(bg.isBackground, isTrue);
      expect(bg.cascadeDepth, 0);
      // The background token is non-cancelling: cancel() is a no-op.
      bg.cancellation.cancel('try');
      expect(bg.cancellation.isCancelled, isFalse);
      expect(bg.throwIfCancelled, returnsNormally);
    });

    test('is a stable singleton', () {
      expect(identical(ZfaContext.background, ZfaContext.background), isTrue);
    });
  });

  group('ZfaContext.childSpan', () {
    test('creates a child with its own span, ledger and cascaded token', () {
      final root = ZfaContext.root();
      final child = root.childSpan(operation: 'child.op');
      expect(child.span?.operation, equals('child.op'));
      expect(child.span?.parent, same(root.span));
      expect(child.cascadeDepth, 0);
      expect(child.cost, isNot(same(root.cost)));
      // Cancelling the root cascades into the child's token.
      root.cancellation.cancel('root');
      expect(child.cancellation.isCancelled, isTrue);
    });

    test('cascadeIncrement raises cascadeDepth', () {
      final root = ZfaContext.root();
      final child = root.childSpan(operation: 'r', cascadeIncrement: 1);
      final grandchild = child.childSpan(operation: 'r2', cascadeIncrement: 1);
      expect(child.cascadeDepth, 1);
      expect(grandchild.cascadeDepth, 2);
    });

    test('timeout installs a deadline on the child', () {
      final root = ZfaContext.root();
      final child = root.childSpan(
        operation: 'bounded',
        timeout: const Duration(seconds: 5),
      );
      expect(child.deadline, isNotNull);
      expect(child.deadline!.isExpired, isFalse);
    });

    test('attributes flow onto the child span', () {
      final root = ZfaContext.root();
      final child = root.childSpan(
        operation: 'tagged',
        attributes: const {'phase': 'ingest'},
      );
      expect(child.span?.attributes['phase'], equals('ingest'));
    });

    test('child cost rolls up into the parent ledger', () {
      final root = ZfaContext.root();
      final child = root.childSpan(operation: 'paid');
      child.cost.record(inputTokens: 7, outputTokens: 3, cost: 0.2);
      root.cost.absorb(child.cost);
      expect(root.cost.inputTokens, 7);
      expect(root.cost.cost, closeTo(0.2, 1e-9));
    });
  });

  group('cascade depth safety', () {
    test('exposes the configured maximum and flags an exceeded depth', () {
      final root = ZfaContext.root();
      final deep = root.childSpan(
        operation: 'deep',
        cascadeIncrement: ZfaContext.maxCascadeDepth + 1,
      );
      expect(deep.isCascadeLimitExceeded, isTrue);
      expect(root.isCascadeLimitExceeded, isFalse);
    });
  });
}
