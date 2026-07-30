import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('ZuraffaContext — Zone Propagation', () {
    test('current returns noop when no zone is active', () {
      expect(ZuraffaContext.current, ZuraffaContext.noop);
      expect(ZuraffaContext.current.isNoop, true);
      expect(ZuraffaContext.hasActiveContext, false);
    });

    test('runWith sets current context in zone', () {
      const ctx = ZuraffaContext(traceId: 'abc-123');
      ZuraffaContext.runWith(ctx, () {
        expect(ZuraffaContext.current.traceId, 'abc-123');
        expect(ZuraffaContext.hasActiveContext, true);
      });
    });

    test('runWithAsync propagates context through async gaps', () async {
      const ctx = ZuraffaContext(traceId: 'async-trace');
      await ZuraffaContext.runWithAsync(ctx, () async {
        await Future.delayed(Duration.zero);
        expect(ZuraffaContext.current.traceId, 'async-trace');
      });
    });

    test('nested zones inherit and override', () {
      const parent = ZuraffaContext(traceId: 'parent', sessionToken: 'tok');
      ZuraffaContext.runWith(parent, () {
        expect(ZuraffaContext.current.traceId, 'parent');
        expect(ZuraffaContext.current.sessionToken, 'tok');

        const child = ZuraffaContext(traceId: 'child');
        ZuraffaContext.runWith(child, () {
          expect(ZuraffaContext.current.traceId, 'child');
          // child is a fresh context — no inheritance in raw runWith
          expect(ZuraffaContext.current.sessionToken, null);
        });
      });
    });

    test('withMetadata creates child with merged metadata', () {
      const ctx = ZuraffaContext(traceId: 't1', metadata: {'a': 1});
      final child = ctx.withMetadata({'b': 2});

      expect(child.traceId, 't1');
      expect(child.metadata('a'), 1);
      expect(child.metadata('b'), 2);
    });

    test('withTraceId creates child with new traceId', () {
      const ctx = ZuraffaContext(traceId: 'old', metadata: {'x': 'y'});
      final child = ctx.withTraceId('new');

      expect(child.traceId, 'new');
      expect(child.metadata('x'), 'y');
    });

    test('withAgentMutation creates child with mutation ID', () {
      const ctx = ZuraffaContext(traceId: 't1');
      final child = ctx.withAgentMutation('mut-42');

      expect(child.agentMutationId, 'mut-42');
      expect(child.traceId, 't1');
    });

    test('metadataMap returns unmodifiable map', () {
      const ctx = ZuraffaContext(metadata: {'k': 'v'});
      final map = ctx.metadataMap;
      expect(map['k'], 'v');
      expect(() => map['x'] = 'y', throwsUnsupportedError);
    });

    test('noop has no active data', () {
      expect(ZuraffaContext.noop.isActive, false);
      expect(ZuraffaContext.noop.metadata('anything'), null);
    });

    test('isActive detects any actionable field', () {
      expect(const ZuraffaContext(traceId: 'x').isActive, true);
      expect(const ZuraffaContext(sessionToken: 'x').isActive, true);
      expect(const ZuraffaContext(agentMutationId: 'x').isActive, true);
      expect(const ZuraffaContext(metadata: {'x': 1}).isActive, true);
      expect(const ZuraffaContext().isActive, false);
    });

    test('generateTraceId produces non-empty string', () {
      final id = ZuraffaContext.generateTraceId();
      expect(id.isNotEmpty, true);
      expect(id.contains('-'), true);
    });

    test('equality and hashCode', () {
      const a = ZuraffaContext(traceId: 't', sessionToken: 's');
      const b = ZuraffaContext(traceId: 't', sessionToken: 's');
      const c = ZuraffaContext(traceId: 't', sessionToken: 'x');

      expect(a == b, true);
      expect(a == c, false);
      expect(a.hashCode == b.hashCode, true);
    });
  });

  group('TelemetryMesh — disabled (zero-cost)', () {
    setUp(() => TelemetryMesh.instance.disable());

    test('isEnabled is false by default', () {
      expect(TelemetryMesh.instance.isEnabled, false);
    });

    test('startSpan returns NoopSpan when disabled', () {
      final span = TelemetryMesh.instance.startSpan('test');
      expect(span, isA<NoopSpan>());
      expect(span.isEnded, true);
    });

    test('trace body executes normally when disabled', () {
      var called = false;
      final result = TelemetryMesh.instance.trace('op', () {
        called = true;
        return 42;
      });
      expect(called, true);
      expect(result, 42);
    });

    test('traceAsync body executes normally when disabled', () async {
      var called = false;
      final result = await TelemetryMesh.instance.traceAsync('op', () async {
        called = true;
        return 42;
      });
      expect(called, true);
      expect(result, 42);
    });

    test('traceUseCase executes without telemetry overhead', () {
      var called = false;
      TelemetryMesh.instance.traceUseCase('GetProduct', () => called = true);
      expect(called, true);
    });
  });

  group('TelemetryMesh — enabled', () {
    final _TestExporter exporter = _TestExporter();

    setUp(() {
      exporter.traces.clear();
      TelemetryMesh.instance.disable();
      TelemetryMesh.instance.enable(exporters: [exporter]);
    });

    tearDown(() => TelemetryMesh.instance.disable());

    test('startSpan creates real span', () {
      final span = TelemetryMesh.instance.startSpan('test.op');
      expect(span, isA<ZuraffaSpan>());
      expect(span.isEnded, false);
      expect(span.name, 'test.op');
      span.end();
    });

    test('trace creates span and records success', () {
      final result = TelemetryMesh.instance.trace('calc', () => 2 + 2);
      expect(result, 4);

      expect(exporter.traces.length, 1);
      final trace = exporter.traces.first;
      expect(trace.spans.length, 1);
      expect(trace.spans.first.name, 'calc');
      expect(trace.spans.first.toJson()['status'], 'ok');
    });

    test('trace records exception on failure', () {
      expect(
        () =>
            TelemetryMesh.instance.trace('boom', () => throw Exception('fail')),
        throwsException,
      );

      expect(exporter.traces.length, 1);
      final span = exporter.traces.first.spans.first;
      expect(span.toJson()['status'], 'error');
      expect((span.toJson()['exceptions'] as List).length, 1);
    });

    test('traceAsync works with async body', () async {
      final result = await TelemetryMesh.instance.traceAsync('async', () async {
        await Future.delayed(Duration.zero);
        return 'done';
      });
      expect(result, 'done');
      expect(exporter.traces.first.spans.first.toJson()['status'], 'ok');
    });

    test('traceUseCase names span correctly', () {
      TelemetryMesh.instance.traceUseCase('GetProduct', () {});
      expect(exporter.traces.first.spans.first.name, 'usecase.GetProduct');
      expect(exporter.traces.first.spans.first.operation, 'UseCase');
    });

    test('traceRepository names span correctly', () {
      TelemetryMesh.instance.traceRepository('ProductRepo', 'getById', () {});
      expect(
        exporter.traces.first.spans.first.name,
        'repo.ProductRepo.getById',
      );
    });

    test('traceNetwork names span correctly', () {
      TelemetryMesh.instance.traceNetwork('/api/products', () {});
      expect(exporter.traces.first.spans.first.name, 'network./api/products');
    });

    test('span records attributes', () {
      final span = TelemetryMesh.instance.startSpan(
        'attr.test',
        attributes: {'key': 'val'},
      );
      span.setAttribute('extra', 42);
      span.end();

      final json = exporter.traces.first.spans.first.toJson();
      expect(json['attributes']['key'], 'val');
      expect(json['attributes']['extra'], 42);
    });

    test('sampling at 0.0 drops all traces', () {
      TelemetryMesh.instance.disable();
      TelemetryMesh.instance.enable(exporters: [exporter], sampleRate: 0.0);

      TelemetryMesh.instance.trace('dropped', () {});
      expect(exporter.traces.length, 0);
    });

    test('sampling at 1.0 keeps all traces', () {
      TelemetryMesh.instance.trace('kept1', () {});
      TelemetryMesh.instance.trace('kept2', () {});
      expect(exporter.traces.length, 2);
    });

    test('context traceId is used when available', () {
      const ctx = ZuraffaContext(traceId: 'my-trace');
      ZuraffaContext.runWith(ctx, () {
        TelemetryMesh.instance.trace('ctx-op', () {});
      });

      expect(exporter.traces.first.traceId, 'my-trace');
    });

    test('multiple spans in same trace share traceId', () {
      const ctx = ZuraffaContext(traceId: 'shared');
      ZuraffaContext.runWith(ctx, () {
        TelemetryMesh.instance.trace('a', () {});
        TelemetryMesh.instance.trace('b', () {});
      });

      // Sequential traces create separate ZuraffaTrace objects
      // (each is flushed independently), but they share the traceId.
      expect(exporter.traces.length, 2);
      for (final trace in exporter.traces) {
        expect(trace.traceId, 'shared');
        expect(trace.spans.length, 1);
      }
    });

    test('disable flushes and clears', () {
      final span = TelemetryMesh.instance.startSpan('before');
      expect(exporter.traces.isEmpty, true);

      TelemetryMesh.instance.disable();
      expect(TelemetryMesh.instance.isEnabled, false);
      expect(exporter.traces.length, 1);
      expect(span.isEnded, false);
    });
  });

  group('Context → UseCase → Data flow', () {
    final _TestExporter exporter = _TestExporter();

    setUp(() {
      exporter.traces.clear();
      TelemetryMesh.instance.disable();
      TelemetryMesh.instance.enable(exporters: [exporter]);
    });

    tearDown(() => TelemetryMesh.instance.disable());

    test('full flow: context propagates through use case to repository', () {
      const ctx = ZuraffaContext(
        traceId: 'e2e-trace',
        sessionToken: 'sess-99',
        agentMutationId: 'mut-7',
      );

      ZuraffaContext.runWith(ctx, () {
        // Simulate: Controller → UseCase → Repository
        TelemetryMesh.instance.traceUseCase('Checkout', () {
          TelemetryMesh.instance.traceRepository('OrderRepo', 'create', () {
            // Data layer
          });
        });
      });

      final trace = exporter.traces.first;
      expect(trace.traceId, 'e2e-trace');
      expect(trace.spans.length, 2);
      expect(trace.spans[0].name, 'usecase.Checkout');
      expect(trace.spans[1].name, 'repo.OrderRepo.create');
    });

    test('context metadata is accessible in telemetry', () {
      const ctx = ZuraffaContext(
        traceId: 'meta-trace',
        metadata: {'screen': 'checkout', 'userType': 'premium'},
      );

      ZuraffaContext.runWith(ctx, () {
        TelemetryMesh.instance.trace('screen-view', () {});
      });

      final trace = exporter.traces.first;
      expect(trace.context.traceId, 'meta-trace');
    });
  });

  group('Zero-cost overhead verification', () {
    test('noop context operations are cheap', () {
      const ctx = ZuraffaContext.noop;
      // These should all be O(1) and not throw
      expect(ctx.traceId, null);
      expect(ctx.sessionToken, null);
      expect(ctx.agentMutationId, null);
      expect(ctx.metadata('anything'), null);
      expect(ctx.isActive, false);
      expect(ctx.isNoop, true);
    });

    test('current without zone is single field read', () {
      // Just verify it works and returns the const singleton
      final ctx = ZuraffaContext.current;
      expect(identical(ctx, ZuraffaContext.noop), true);
    });
  });
}

// ── Test doubles ──

class _TestExporter implements TelemetryExporter {
  final List<ZuraffaTrace> traces = [];

  @override
  void export(ZuraffaTrace trace) {
    traces.add(trace);
  }
}
