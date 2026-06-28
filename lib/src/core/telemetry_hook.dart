import 'package:opentelemetry/api.dart' show Attribute, Span;

import 'hook.dart';
import 'otel_tracer.dart';

/// Automatically wraps every UseCase execution in an OpenTelemetry span.
///
/// Replaces manual `OtelTracer.instance.trace()` calls. Once registered,
/// every `UseCase.call()` and `StreamUseCase.call()` is traced automatically
/// — no developer action needed.
///
/// ## What It Records
///
/// - **Span name**: `usecase.{UseCaseName}` (e.g. `usecase.GetDealListUseCase`)
/// - **On success**: status OK, `usecase.duration_ms` attribute
/// - **On failure**: status ERROR, failure type/message/stacktrace
///
/// ## Usage
///
/// ```dart
/// // Typically combined with OtelFailureReporter for full observability:
/// await Zuraffa.enableOtelReporting(
///   collectorEndpoint: Uri.parse('https://otel.example.com/v1/traces'),
///   serviceName: 'my_app',
/// );
///
/// // Now every UseCase is automatically traced:
/// Zuraffa.registerHook(TelemetryHook());
/// ```
///
/// ## Filtering
///
/// Use [onlyUseCases] (whitelist) and [excludeUseCases] (blacklist) to
/// control which UseCases get traced:
///
/// ```dart
/// // Trace only specific UseCases:
/// Zuraffa.registerHook(TelemetryHook(
///   onlyUseCases: {'GetDealListUseCase', 'CreateBarcodeScanUseCase'},
/// ));
///
/// // Trace everything except noisy ones:
/// Zuraffa.registerHook(TelemetryHook(
///   excludeUseCases: {'WatchConnectivityUseCase', 'GetCacheUseCase'},
/// ));
/// ```
///
/// When both are set and contain the same UseCase, [excludeUseCases] wins.
class TelemetryHook extends Hook {
  /// Creates a telemetry hook with optional filtering.
  ///
  /// - [onlyUseCases]: if non-empty, only these UseCases are traced.
  ///   Default: empty (trace all).
  /// - [excludeUseCases]: these UseCases are never traced.
  ///   Default: empty. Takes precedence over [onlyUseCases].
  /// - [spanNamePrefix]: prefix for span names. Default: `'usecase'`.
  TelemetryHook({
    this.onlyUseCases = const {},
    this.excludeUseCases = const {},
    this.spanNamePrefix = 'usecase',
  });

  /// Whitelist of UseCase runtime type names to trace.
  ///
  /// If non-empty, only UseCases whose `runtimeType.toString()` is in this
  /// set will be traced. All others are skipped.
  final Set<String> onlyUseCases;

  /// Blacklist of UseCase runtime type names to exclude from tracing.
  ///
  /// Takes precedence over [onlyUseCases] — a UseCase in both sets is
  /// excluded.
  final Set<String> excludeUseCases;

  /// Prefix for span names. Defaults to `'usecase'`.
  ///
  /// Produces spans like `usecase.GetDealListUseCase`.
  final String spanNamePrefix;

  /// Metadata key used to stash the span across phases.
  static const _spanKey = '_telemetry_span';

  @override
  String get id => 'zuraffa-telemetry';

  /// Telemetry needs all three phases:
  /// - pre: start the span
  /// - success: end span with OK status
  /// - failure: end span with ERROR status
  @override
  Set<HookPhase> get phases => const {
    HookPhase.pre,
    HookPhase.success,
    HookPhase.failure,
  };

  @override
  bool shouldTrigger(HookContext context, HookPhase phase) {
    // excludeUseCases always wins
    if (excludeUseCases.contains(context.useCaseName)) return false;

    // If onlyUseCases is non-empty, only fire for those
    if (onlyUseCases.isNotEmpty) {
      return onlyUseCases.contains(context.useCaseName);
    }

    return true;
  }

  @override
  Future<void> execute(HookContext context, HookPhase phase) async {
    switch (phase) {
      case HookPhase.pre:
        _startSpan(context);
      case HookPhase.success:
        _endSpanSuccess(context);
      case HookPhase.failure:
        _endSpanFailure(context);
    }
  }

  void _startSpan(HookContext context) {
    final spanName = '$spanNamePrefix.${context.useCaseName}';
    final span = OtelTracer.instance.startSpan(
      spanName,
      attributes: [
        Attribute.fromString('usecase.name', context.useCaseName),
        Attribute.fromString('usecase.phase', 'started'),
      ],
    );
    // Stash the span in the shared metadata bag for later phases
    context.metadata[_spanKey] = span;
  }

  void _endSpanSuccess(HookContext context) {
    final span = context.metadata[_spanKey] as Span?;
    if (span == null) return;

    if (context.duration != null) {
      span.setAttribute(
        Attribute.fromInt(
          'usecase.duration_ms',
          context.duration!.inMilliseconds,
        ),
      );
    }
    span.setAttribute(Attribute.fromString('usecase.phase', 'success'));

    OtelTracer.instance.endSpan(span);
    context.metadata.remove(_spanKey);
  }

  void _endSpanFailure(HookContext context) {
    final span = context.metadata[_spanKey] as Span?;
    if (span == null) return;

    span.setAttribute(Attribute.fromString('usecase.phase', 'failure'));

    if (context.failure != null) {
      OtelTracer.instance.endSpanWithError(
        span,
        context.failure!,
        context.failure!.stackTrace ?? StackTrace.current,
      );
    } else {
      OtelTracer.instance.endSpan(span);
    }

    context.metadata.remove(_spanKey);
  }
}
