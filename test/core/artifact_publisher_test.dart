// Unit tests for ArtifactPublisher, ArtifactContext, and MinIOArtifactHook
// key building logic.
//
// These tests run without any external dependencies (no MinIO needed).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

// ---------------------------------------------------------------------------
// Test hook that captures the ArtifactContext for inspection
// ---------------------------------------------------------------------------

class CapturingHook extends ArtifactHook {
  ArtifactContext? lastContext;
  int callCount = 0;

  @override
  String get id => 'test-capturing';

  @override
  Future<void> onPublish(ArtifactContext context) async {
    lastContext = context;
    callCount++;
  }
}

class RejectingHook extends ArtifactHook {
  int checkCount = 0;

  @override
  String get id => 'test-rejecting';

  @override
  bool shouldPublish(ArtifactContext context) {
    checkCount++;
    return false;
  }

  @override
  Future<void> onPublish(ArtifactContext context) async {
    fail('Should not be called');
  }
}

class ThrowingHook extends ArtifactHook {
  @override
  String get id => 'test-throwing';

  @override
  Future<void> onPublish(ArtifactContext context) async {
    throw Exception('Hook exploded');
  }
}

void main() {
  group('ArtifactContext', () {
    test('creates with required fields and defaults', () {
      final ctx = ArtifactContext(
        id: 'test-123',
        data: 'hello',
        contentType: 'text/plain',
        reason: 'failure',
      );

      expect(ctx.id, 'test-123');
      expect(ctx.data, 'hello');
      expect(ctx.contentType, 'text/plain');
      expect(ctx.reason, 'failure');
      expect(ctx.source, isNull);
      expect(ctx.label, isNull);
      expect(ctx.metadata, isEmpty);
      expect(ctx.stackTrace, isNull);
      expect(ctx.pathSegments, isEmpty);
      expect(ctx.timestamp, isNotNull);
    });

    test('pathSegments defaults to empty list', () {
      final ctx = ArtifactContext(
        id: 'test',
        data: 'x',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(ctx.pathSegments, equals(const <String>[]));
    });

    test('pathSegments is passed through', () {
      final ctx = ArtifactContext(
        id: 'test',
        data: 'x',
        contentType: 'text/plain',
        reason: 'failure',
        pathSegments: ['tr', 'gratis'],
      );

      expect(ctx.pathSegments, equals(['tr', 'gratis']));
    });

    test('convenience getters work correctly', () {
      final failCtx = ArtifactContext(
        id: 'f',
        data: '<html></html>',
        contentType: 'text/html',
        reason: 'failure',
      );
      expect(failCtx.reason, 'failure');
      expect(failCtx.reason == 'scan', isFalse);
      expect(failCtx.isText, isTrue);
      expect(failCtx.isBinary, isFalse);
      expect(failCtx.isHtml, isTrue);
      expect(failCtx.isImage, isFalse);
      expect(failCtx.dataAsString, '<html></html>');
      expect(failCtx.dataAsBytes, isNull);

      final scanCtx = ArtifactContext(
        id: 's',
        data: Uint8List(10),
        contentType: 'image/jpeg',
        reason: 'scan',
      );
      expect(scanCtx.reason == 'failure', isFalse);
      expect(scanCtx.reason, 'scan');
      expect(scanCtx.isText, isFalse);
      expect(scanCtx.isBinary, isTrue);
      expect(scanCtx.isImage, isTrue);
      expect(scanCtx.dataAsString, isNull);
      expect(scanCtx.dataAsBytes, isNotNull);
    });

    test('typed metadata access', () {
      final ctx = ArtifactContext(
        id: 'test',
        data: '',
        contentType: 'text/plain',
        reason: 'debug',
        metadata: {'count': 42, 'name': 'test'},
      );

      expect(ctx.get<int>('count'), 42);
      expect(ctx.get<String>('name'), 'test');
      expect(ctx.get<String>('missing'), isNull);
    });
  });

  group('ArtifactPublisher', () {
    late ArtifactPublisher publisher;
    late CapturingHook hook;

    setUp(() {
      // Use the singleton but clear hooks for isolation
      publisher = ArtifactPublisher.instance;
      publisher.clear();
      hook = CapturingHook();
      publisher.register(hook);
    });

    tearDown(() {
      publisher.clear();
    });

    test('publish() passes all fields to hook', () async {
      await publisher.publish(
        'test data',
        id: 'abc-123',
        contentType: 'text/html; charset=utf-8',
        reason: 'failure',
        source: 'TestSource',
        label: 'TestLabel',
        metadata: {'key': 'value'},
        pathSegments: ['seg1', 'seg2'],
      );

      expect(hook.callCount, 1);
      final ctx = hook.lastContext!;
      expect(ctx.id, 'abc-123');
      expect(ctx.data, 'test data');
      expect(ctx.contentType, 'text/html; charset=utf-8');
      expect(ctx.reason, 'failure');
      expect(ctx.source, 'TestSource');
      expect(ctx.label, 'TestLabel');
      expect(ctx.metadata, {'key': 'value'});
      expect(ctx.pathSegments, ['seg1', 'seg2']);
    });

    test('publish() with empty pathSegments by default', () async {
      await publisher.publish(
        'data',
        id: 'x',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(hook.lastContext!.pathSegments, isEmpty);
    });

    test('hooks are called in priority order', () async {
      final order = <String>[];

      publisher.clear();
      publisher.register(_OrderTrackingHook('low', 0, order));
      publisher.register(_OrderTrackingHook('high', 100, order));
      publisher.register(_OrderTrackingHook('mid', 50, order));

      await publisher.publish(
        'x',
        id: 'test',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(order, ['low', 'mid', 'high']);
    });

    test('shouldPublish filters hooks', () async {
      final rejecting = RejectingHook();
      publisher.register(rejecting);

      await publisher.publish(
        'x',
        id: 'test',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(rejecting.checkCount, greaterThanOrEqualTo(1));
      expect(hook.callCount, 1); // CapturingHook still runs
    });

    test('hook exception does not block other hooks', () async {
      publisher.register(ThrowingHook());

      // CapturingHook has priority 0, ThrowingHook has priority 0
      // Both should be attempted; CapturingHook should still get called
      await publisher.publish(
        'x',
        id: 'test',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(hook.callCount, 1);
    });

    test('register replaces hook with same id', () async {
      final hook2 = CapturingHook();
      publisher.register(hook2); // Same id as hook

      await publisher.publish(
        'x',
        id: 'test',
        contentType: 'text/plain',
        reason: 'debug',
      );

      expect(hook.callCount, 0); // replaced
      expect(hook2.callCount, 1);
    });
  });

  group('FailureContext backward compatibility', () {
    test('toArtifactContext preserves pathSegments', () {
      final fc = FailureContext(
        failure: const NetworkFailure('timeout'),
        stackTrace: StackTrace.current,
        useCaseName: 'TestUseCase',
        metadata: {'taskId': '123', 'html': '<div>fail</div>'},
        pathSegments: ['us', 'amazon'],
      );

      final ac = fc.toArtifactContext();

      expect(ac.pathSegments, ['us', 'amazon']);
      expect(ac.reason, 'failure');
      expect(ac.source, 'TestUseCase');
      expect(ac.id, '123');
    });

    test('toArtifactContext defaults pathSegments to empty', () {
      final fc = FailureContext(
        failure: const NetworkFailure('timeout'),
        stackTrace: StackTrace.current,
      );

      final ac = fc.toArtifactContext();
      expect(ac.pathSegments, isEmpty);
    });
  });
}

class _OrderTrackingHook extends ArtifactHook {
  final String _id;
  final int _priority;
  final List<String> _order;

  _OrderTrackingHook(this._id, this._priority, this._order);

  @override
  String get id => _id;

  @override
  int get priority => _priority;

  @override
  Future<void> onPublish(ArtifactContext context) async {
    _order.add(_id);
  }
}
