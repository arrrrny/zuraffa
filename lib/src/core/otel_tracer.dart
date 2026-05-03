import 'dart:async';

import 'package:logging/logging.dart';
import 'package:opentelemetry/api.dart'
    show
        Attribute,
        Context,
        Span,
        SpanKind,
        StatusCode,
        contextWithSpan,
        globalTracerProvider,
        Tracer;

// ---------------------------------------------------------------------------
// OtelTracer
// ---------------------------------------------------------------------------

/// Thin singleton for creating and managing application-level OTel traces.
///
/// Works alongside [OtelFailureReporter] — both share the same global
/// [TracerProvider] registered at startup via [OtelFailureReporter.initialize].
///
/// ## Purpose
///
/// [OtelFailureReporter] handles the *error path* — it automatically wraps
/// each [AppFailure] in a span. [OtelTracer] handles the *happy path and
/// business operations* — you decide which operations are worth tracing
/// and what attributes to attach.
///
/// ## Usage
///
/// ```dart
/// // Wrap a business operation in a span (recommended — handles end/error automatically)
/// final order = await OtelTracer.instance.trace(
///   'checkout.process',
///   attributes: [Attribute.fromString('order.id', orderId)],
///   () async {
///     return await processOrder(orderId);
///   },
/// );
///
/// // Manual span control
/// final span = OtelTracer.instance.startSpan(
///   'inventory.reserve',
///   attributes: [Attribute.fromString('product.id', productId)],
/// );
/// try {
///   await reserveInventory(productId);
///   span.end();
/// } catch (e, st) {
///   OtelTracer.instance.endSpanWithError(span, e, st);
/// }
/// ```
///
/// ## Trace Context in Artifacts
///
/// When [ArtifactPublisher] publishes an artifact, it calls
/// [OtelTracer.currentTraceId] and [OtelTracer.currentSpanId] to stamp
/// the active span context onto the artifact. This lets you navigate from
/// any artifact in storage directly to the trace in Jaeger/Grafana.
///
/// ## Initialization
///
/// [OtelTracer] becomes active automatically when [OtelFailureReporter]
/// registers the global [TracerProvider] during [Zuraffa.enableOtelReporting].
/// No separate setup is required.
class OtelTracer {
  OtelTracer._();

  static final OtelTracer _instance = OtelTracer._();

  /// The singleton instance.
  static OtelTracer get instance => _instance;

  static final Logger _logger = Logger('OtelTracer');

  /// The instrumentation name used when getting the [Tracer].
  ///
  /// Defaults to `'zuraffa-tracer'`. Override before first use if you want
  /// a custom scope name to appear in your telemetry backend.
  String instrumentationName = 'zuraffa-tracer';

  // ---------------------------------------------------------------------------
  // Active span context
  // ---------------------------------------------------------------------------

  /// The W3C trace ID of the currently active span, or `null` if no span
  /// is active or the active span context is invalid.
  ///
  /// Format: 32 lowercase hex characters (128-bit), e.g.
  /// `'4bf92f3577b34da6a3ce929d0e0e4736'`
  ///
  /// Used by [ArtifactPublisher] to stamp artifacts with the active trace ID
  /// so you can cross-reference from storage back to the trace.
  String? get currentTraceId {
    try {
      final spanCtx = Context.current.spanContext;
      if (!spanCtx.isValid) return null;
      final id = spanCtx.traceId.toString();
      // Guard against the all-zeros invalid trace id
      return (id.isEmpty || RegExp(r'^0+$').hasMatch(id)) ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// The W3C span ID of the currently active span, or `null` if no span
  /// is active or the active span context is invalid.
  ///
  /// Format: 16 lowercase hex characters (64-bit), e.g.
  /// `'00f067aa0ba902b7'`
  String? get currentSpanId {
    try {
      final spanCtx = Context.current.spanContext;
      if (!spanCtx.isValid) return null;
      final id = spanCtx.spanId.toString();
      return (id.isEmpty || RegExp(r'^0+$').hasMatch(id)) ? null : id;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Span lifecycle
  // ---------------------------------------------------------------------------

  /// Start a new span as a child of the currently active context.
  ///
  /// You are responsible for calling [endSpan] or [endSpanWithError] when done.
  /// Prefer [trace] when possible — it handles lifecycle automatically.
  ///
  /// ```dart
  /// final span = OtelTracer.instance.startSpan(
  ///   'payment.authorise',
  ///   attributes: [Attribute.fromString('payment.provider', 'stripe')],
  /// );
  /// ```
  Span startSpan(
    String name, {
    List<Attribute> attributes = const [],
    SpanKind kind = SpanKind.internal,
    Context? parentContext,
  }) {
    try {
      final tracer = _getTracer();
      final ctx = parentContext ?? Context.current;
      final span = tracer.startSpan(
        name,
        context: ctx,
        kind: kind,
        attributes: attributes,
      );
      return span;
    } catch (e) {
      _logger.warning('OtelTracer.startSpan failed for "$name": $e');
      rethrow;
    }
  }

  /// End a span successfully.
  void endSpan(Span span) {
    try {
      span.end();
    } catch (e) {
      _logger.warning('OtelTracer.endSpan failed: $e');
    }
  }

  /// End a span in an error state, recording the exception.
  void endSpanWithError(Span span, Object error, [StackTrace? stackTrace]) {
    try {
      span.setStatus(StatusCode.error, error.toString());
      span.recordException(error, stackTrace: stackTrace ?? StackTrace.current);
      span.end();
    } catch (e) {
      _logger.warning('OtelTracer.endSpanWithError failed: $e');
    }
  }

  /// Attach a span to the current context and run [fn] within it.
  ///
  /// The span is active for the duration of [fn], meaning [currentTraceId]
  /// and [currentSpanId] will return its IDs while inside [fn]. The span
  /// is ended automatically — with error status if [fn] throws.
  ///
  /// ```dart
  /// final result = await OtelTracer.instance.trace(
  ///   'cart.checkout',
  ///   attributes: [Attribute.fromString('cart.id', cartId)],
  ///   () async => await checkoutService.process(cartId),
  /// );
  /// ```
  Future<T> trace<T>(
    String name,
    Future<T> Function() fn, {
    List<Attribute> attributes = const [],
    SpanKind kind = SpanKind.internal,
  }) {
    // Capture the parent context *before* forking so that the new span is
    // correctly linked as a child of whatever span was active at the call-site.
    final parentContext = Context.current;

    return runZoned(() async {
      final span = startSpan(
        name,
        attributes: attributes,
        kind: kind,
        parentContext: parentContext,
      );

      final spanContext = contextWithSpan(Context.current, span);
      // ignore: experimental_member_use
      final token = Context.attach(spanContext);

      try {
        final result = await fn();
        endSpan(span);
        // ignore: experimental_member_use
        Context.detach(token);
        return result;
      } catch (e, st) {
        endSpanWithError(span, e, st);
        // ignore: experimental_member_use
        Context.detach(token);
        rethrow;
      }
    });
  }

  /// Synchronous variant of [trace] for non-async operations.
  T traceSync<T>(
    String name,
    T Function() fn, {
    List<Attribute> attributes = const [],
    SpanKind kind = SpanKind.internal,
  }) {
    final parentContext = Context.current;

    return runZoned(() {
      final span = startSpan(
        name,
        attributes: attributes,
        kind: kind,
        parentContext: parentContext,
      );

      final spanContext = contextWithSpan(Context.current, span);
      // ignore: experimental_member_use
      final token = Context.attach(spanContext);

      try {
        final result = fn();
        endSpan(span);
        // ignore: experimental_member_use
        Context.detach(token);
        return result;
      } catch (e, st) {
        endSpanWithError(span, e, st);
        // ignore: experimental_member_use
        Context.detach(token);
        rethrow;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Span enrichment
  // ---------------------------------------------------------------------------

  /// Add an event to [span] — a timestamped annotation within the span.
  ///
  /// Use events for notable moments during a span's lifetime, e.g.:
  /// ```dart
  /// OtelTracer.instance.addEvent(
  ///   span,
  ///   'cache.miss',
  ///   attributes: [Attribute.fromString('cache.key', key)],
  /// );
  /// ```
  void addEvent(
    Span span,
    String name, {
    List<Attribute> attributes = const [],
  }) {
    try {
      span.addEvent(name, attributes: attributes);
    } catch (e) {
      _logger.warning('OtelTracer.addEvent failed: $e');
    }
  }

  /// Set an attribute on [span].
  void setAttribute(Span span, Attribute attribute) {
    try {
      span.setAttribute(attribute);
    } catch (e) {
      _logger.warning('OtelTracer.setAttribute failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Tracer _getTracer() => globalTracerProvider.getTracer(instrumentationName);
}
