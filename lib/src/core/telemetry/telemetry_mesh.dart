import 'dart:async';
import '../context/zuraffa_context.dart';

/// Global telemetry coordinator for zuraffa.
///
/// [TelemetryMesh] is a singleton that manages trace collection, span
/// creation, and exporter dispatch. When disabled (the default), every
/// operation is a no-op with zero allocation overhead.
class TelemetryMesh {
  TelemetryMesh._();
  static final TelemetryMesh instance = TelemetryMesh._();

  bool _enabled = false;
  double _sampleRate = 1.0;
  final List<TelemetryExporter> _exporters = [];
  final _activeTraces = <String, ZuraffaTrace>{};

  // ── Configuration ──

  bool get isEnabled => _enabled;
  double get sampleRate => _sampleRate;

  /// Enable telemetry with the given exporters and sample rate.
  ///
  /// Clears any prior session state (exporters, active traces) before applying
  /// the new configuration.
  void enable({
    required List<TelemetryExporter> exporters,
    double sampleRate = 1.0,
  }) {
    _exporters.clear();
    _activeTraces.clear();
    _exporters.addAll(exporters);
    _sampleRate = sampleRate.clamp(0.0, 1.0);
    _enabled = true;
  }

  /// Disable telemetry. All active traces are flushed and cleared.
  void disable() {
    _enabled = false;
    _flushAll();
    _activeTraces.clear();
    _exporters.clear();
  }

  // ── Span API ──

  /// Start a new span under the current trace.
  ///
  /// If telemetry is disabled, returns [NoopSpan] immediately.
  /// If sampling drops this trace, returns [NoopSpan].
  ZuraffaSpan startSpan(
    String name, {
    String? operation,
    Map<String, dynamic>? attributes,
  }) {
    if (!_enabled) return NoopSpan.instance;

    final ctx = ZuraffaContext.current;
    final traceId = ctx.traceId ?? _generateTraceId();

    // Sampling check
    if (!_shouldSample(traceId)) return NoopSpan.instance;

    final trace = _activeTraces.putIfAbsent(
      traceId,
      () => ZuraffaTrace(traceId: traceId, context: ctx),
    );

    final span = ZuraffaSpan(
      name: name,
      operation: operation,
      traceId: traceId,
      parentId: trace.currentSpanId,
      attributes: attributes,
    );

    trace.addSpan(span);
    trace.activeSpanCount++;
    return span;
  }

  /// Execute [body] inside a traced span.
  T trace<T>(
    String name,
    T Function() body, {
    String? operation,
    Map<String, dynamic>? attributes,
  }) {
    final span = startSpan(name, operation: operation, attributes: attributes);
    // Skip zone propagation for no-op spans — body runs in caller's context.
    if (identical(span, NoopSpan.instance)) {
      return _runBody(span, body);
    }
    // Propagate traceId so child spans inherit it.
    return _runInTraceZoneIfNeeded(span.traceId, () => _runBody(span, body));
  }

  /// Async variant of [trace].
  Future<T> traceAsync<T>(
    String name,
    Future<T> Function() body, {
    String? operation,
    Map<String, dynamic>? attributes,
  }) async {
    final span = startSpan(name, operation: operation, attributes: attributes);
    return _runInTraceZoneIfNeeded(span.traceId, () async {
      return _runBodyAsync(span, body);
    });
  }

  /// Common sync body execution with span lifecycle.
  static T _runBody<T>(ZuraffaSpan span, T Function() body) {
    try {
      final result = body();
      span.setStatus(SpanStatus.ok);
      return result;
    } catch (e, st) {
      span.recordException(e, st);
      span.setStatus(SpanStatus.error);
      rethrow;
    } finally {
      span.end();
    }
  }

  /// Common async body execution with span lifecycle.
  static Future<T> _runBodyAsync<T>(
    ZuraffaSpan span,
    Future<T> Function() body,
  ) async {
    try {
      final result = await body();
      span.setStatus(SpanStatus.ok);
      return result;
    } catch (e, st) {
      span.recordException(e, st);
      span.setStatus(SpanStatus.error);
      rethrow;
    } finally {
      span.end();
    }
  }

  // ── UseCase / Repository helpers ──

  /// Trace a UseCase execution under the span name `usecase.<useCaseName>`.
  T traceUseCase<T>(String useCaseName, T Function() body) =>
      trace('usecase.$useCaseName', body, operation: 'UseCase');

  Future<T> traceUseCaseAsync<T>(
    String useCaseName,
    Future<T> Function() body,
  ) => traceAsync('usecase.$useCaseName', body, operation: 'UseCase');

  /// Trace a repository call.
  T traceRepository<T>(String repoName, String method, T Function() body) =>
      trace('repo.$repoName.$method', body, operation: 'Repository');

  Future<T> traceRepositoryAsync<T>(
    String repoName,
    String method,
    Future<T> Function() body,
  ) => traceAsync('repo.$repoName.$method', body, operation: 'Repository');

  /// Trace a network request.
  T traceNetwork<T>(String endpoint, T Function() body) =>
      trace('network.$endpoint', body, operation: 'HTTP');

  Future<T> traceNetworkAsync<T>(String endpoint, Future<T> Function() body) =>
      traceAsync('network.$endpoint', body, operation: 'HTTP');

  // ── Trace lifecycle ──

  /// Called by [ZuraffaSpan.end] when a span finishes.
  void _onSpanEnded(String traceId) {
    final trace = _activeTraces[traceId];
    if (trace == null) return;
    trace.activeSpanCount--;
    if (trace.activeSpanCount == 0) {
      _completeTrace(traceId);
    }
  }

  void _completeTrace(String traceId) {
    final trace = _activeTraces.remove(traceId);
    if (trace == null) return;
    for (final ex in _exporters) {
      _safeExport(ex, trace);
    }
  }

  void _flushAll() {
    for (final trace in _activeTraces.values) {
      for (final ex in _exporters) {
        _safeExport(ex, trace);
      }
    }
  }

  void _safeExport(TelemetryExporter ex, ZuraffaTrace trace) {
    try {
      ex.export(trace);
    } catch (_) {
      // Isolate exporter failures — never let an exporter crash the caller.
    }
  }

  bool _shouldSample(String traceId) {
    if (_sampleRate >= 1.0) return true;
    if (_sampleRate <= 0.0) return false;
    final hash = traceId.hashCode.abs();
    return (hash % 1000) < (_sampleRate * 1000);
  }

  String _generateTraceId() => ZuraffaContext.generateTraceId();

  T _runInTraceZoneIfNeeded<T>(String traceId, T Function() body) {
    final ctx = ZuraffaContext.current;
    if (ctx.traceId != traceId) {
      return ZuraffaContext.runWith(ctx.withTraceId(traceId), body);
    }
    return body();
  }
}

// ── Span ──

/// A single operation span within a trace.
class ZuraffaSpan {
  ZuraffaSpan({
    required this.name,
    this.operation,
    required this.traceId,
    this.parentId,
    Map<String, dynamic>? attributes,
  }) : attributes = Map<String, dynamic>.of(attributes ?? const {}),
       spanId = _generateSpanId(),
       _startTime = DateTime.now();

  final String name;
  final String? operation;
  final String traceId;
  final String spanId;
  final String? parentId;
  final Map<String, dynamic> attributes;

  final DateTime _startTime;
  DateTime? _endTime;
  SpanStatus _status = SpanStatus.unset;
  final List<SpanException> _exceptions = [];
  bool _ended = false;

  bool get isEnded => _ended;
  Duration? get duration => _endTime?.difference(_startTime);

  void setStatus(SpanStatus status) => _status = status;

  void setAttribute(String key, dynamic value) {
    attributes[key] = value;
  }

  void recordException(Object exception, [StackTrace? stackTrace]) {
    _exceptions.add(
      SpanException(
        exception: exception.toString(),
        stackTrace: stackTrace?.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  void end() {
    if (_ended) return;
    _ended = true;
    _endTime = DateTime.now();
    TelemetryMesh.instance._onSpanEnded(traceId);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'operation': operation,
    'traceId': traceId,
    'spanId': spanId,
    'parentId': parentId,
    'startTime': _startTime.toIso8601String(),
    'endTime': _endTime?.toIso8601String(),
    'durationMs': duration?.inMilliseconds,
    'status': _status.name,
    'attributes': attributes,
    'exceptions': _exceptions.map((e) => e.toJson()).toList(),
  };

  static int _spanIdCounter = 0;

  static String _generateSpanId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _spanIdCounter = (_spanIdCounter + 1) & 0xFFFF;
    return 'span-${now.toRadixString(16)}-${_spanIdCounter.toRadixString(16)}';
  }
}

/// No-op span returned when telemetry is disabled or trace is unsampled.
class NoopSpan implements ZuraffaSpan {
  NoopSpan._() : _startTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Shared singleton — no allocation per call.
  static final NoopSpan instance = NoopSpan._();

  @override
  String get name => 'noop';
  @override
  String? get operation => null;
  @override
  String get traceId => 'noop';
  @override
  String get spanId => 'noop';
  @override
  String? get parentId => null;
  @override
  Map<String, dynamic> get attributes => const {};
  @override
  bool get isEnded => true;
  @override
  Duration? get duration => null;

  @override
  void setStatus(SpanStatus _) {}
  @override
  void setAttribute(String _, dynamic _) {}
  @override
  void recordException(Object _, [StackTrace? _]) {}
  @override
  void end() {}
  @override
  Map<String, dynamic> toJson() => const {};

  // Private interface conformance
  @override
  final DateTime _startTime;
  @override
  DateTime? _endTime;
  @override
  SpanStatus _status = SpanStatus.unset;
  @override
  final List<SpanException> _exceptions = const [];
  @override
  bool _ended = true;
}

// ── Trace ──

/// A complete trace — a tree of spans sharing a traceId.
class ZuraffaTrace {
  ZuraffaTrace({required this.traceId, required this.context});

  final String traceId;
  final ZuraffaContext context;
  final List<ZuraffaSpan> spans = [];

  /// Number of spans that have started but not yet ended.
  /// Used to avoid flushing the trace before all nested spans complete.
  int activeSpanCount = 0;

  String? get currentSpanId => spans.isNotEmpty ? spans.last.spanId : null;

  void addSpan(ZuraffaSpan span) => spans.add(span);

  Map<String, dynamic> toJson() => {
    'traceId': traceId,
    'context': {
      'traceId': context.traceId,
      'agentMutationId': context.agentMutationId,
    },
    'spanCount': spans.length,
    'spans': spans.map((s) => s.toJson()).toList(),
  };
}

// ── Exporter ──

abstract class TelemetryExporter {
  void export(ZuraffaTrace trace);
}

/// Console exporter for development/debugging.
class ConsoleExporter implements TelemetryExporter {
  @override
  void export(ZuraffaTrace trace) {
    // ignore: avoid_print
    print('[Telemetry] Trace ${trace.traceId} — ${trace.spans.length} span(s)');
    for (final span in trace.spans) {
      // ignore: avoid_print
      print(
        '  ${span.name}: ${span.duration?.inMilliseconds}ms [${span._status.name}]',
      );
    }
  }
}

// ── Status & Exception ──

enum SpanStatus { unset, ok, error }

class SpanException {
  SpanException({
    required this.exception,
    this.stackTrace,
    required this.timestamp,
  });
  final String exception;
  final String? stackTrace;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'exception': exception,
    'stackTrace': stackTrace,
    'timestamp': timestamp.toIso8601String(),
  };
}
