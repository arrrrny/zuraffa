import '../signals/signal_result.dart';

/// Composite key for interceptor registry lookup, grouping by both input and output types.
class _TypePair {
  final Type inType;
  final Type outType;

  const _TypePair(this.inType, this.outType);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TypePair &&
          runtimeType == other.runtimeType &&
          inType == other.inType &&
          outType == other.outType;

  @override
  int get hashCode => Object.hash(inType, outType);

  @override
  String toString() => '_TypePair($inType, $outType)';
}

/// Signature for an interceptor function that wraps a [ZuraffaUseCase]
/// invocation.
///
/// The interceptor receives the [request] (the input parameters) and a
/// [next] function that invokes the next interceptor in the chain (or the
/// original UseCase if this is the last interceptor). The interceptor
/// returns the [SignalResult] from calling [next], optionally transforming
/// it via [SignalResult.map] or by creating a replacement.
///
/// ## Example
///
/// ```dart
/// // Logging interceptor - observes but does not modify.
/// SignalResult<Order> loggingInterceptor(
///   CreateOrderParams request,
///   SignalResult<Order> Function(CreateOrderParams) next,
/// ) {
///   print('Creating order: $request');
///   final result = next(request);
///   result.onSuccess((order) => print('Order created: $order'));
///   return result;
/// }
/// ```
typedef InterceptorFunction<In, Out> =
    SignalResult<Out> Function(
      In request,
      SignalResult<Out> Function(In request) next,
    );

/// A registered interceptor entry with an optional descriptive name.
///
/// Each entry wraps an [InterceptorFunction] and carries a [name]
/// for debugging and registry inspection. Interceptors execute in
/// registration order; each calls [next] to continue the chain.
class InterceptorEntry<In, Out> {
  /// The interceptor function.
  final InterceptorFunction<In, Out> handler;

  /// Optional descriptive name for debugging and registry inspection.
  final String name;

  /// Creates an interceptor entry.
  const InterceptorEntry({required this.handler, this.name = 'anonymous'});

  @override
  String toString() => 'InterceptorEntry($name)';
}

/// A keyed registry of interceptor chains, one list per UseCase type pair.
///
/// The registry maps a UseCase `(In, Out)` type pair to an ordered list of
/// [InterceptorEntry] instances. When [execute] is called, the
/// entries are chained so that each interceptor's `next` function
/// invokes the next one in the list (or the original UseCase).
///
/// Interceptors run in registration order. Each interceptor
/// receives the original request and a [next] callback. Calling
/// [next] continues the chain; skipping it short-circuits.
///
/// ## Lifecycle
///
/// The registry lives on the [ZuraffaDIContainer] and is cleared
/// when the container is reset.
class InterceptorRegistry {
  /// Internal map: (In, Out) type pair -> ordered list of interceptor entries.
  /// Key is a composite of both input and output types to prevent collisions.
  final Map<_TypePair, List<InterceptorEntry<dynamic, dynamic>>> _entries = {};

  /// Whether any interceptors are registered.
  bool get isEmpty => _entries.isEmpty;

  /// Returns all registered interceptor entries for type pair `(In, Out)`,
  /// or an empty list if none are registered.
  List<InterceptorEntry<In, Out>> entriesFor<In, Out>() {
    final key = _TypePair(In, Out);
    final raw = _entries[key];
    if (raw == null || raw.isEmpty) return const [];
    return raw.cast<InterceptorEntry<In, Out>>();
  }

  /// Register an interceptor for UseCase type pair `(In, Out)`.
  ///
  /// The [handler] will be called with the request and a [next]
  /// function that invokes the next interceptor in the chain.
  /// Multiple interceptors for the same type pair run in registration
  /// order (first registered = outermost).
  void register<In, Out>(InterceptorEntry<In, Out> entry) {
    final key = _TypePair(In, Out);
    (_entries[key] ??= []).add(entry);
  }

  /// Builds a chained interceptor pipeline for type [In, Out].
  ///
  /// Returns a function that, when called with [request], runs
  /// all registered interceptors in order. The [tail] function
  /// is the innermost call -- typically the original UseCase
  /// invocation.
  ///
  /// If no interceptors are registered, returns [tail] directly
  /// (zero overhead).
  SignalResult<Out> Function(In request) chain<In, Out>(
    SignalResult<Out> Function(In request) tail,
  ) {
    final entries = entriesFor<In, Out>();
    if (entries.isEmpty) return tail;

    // Build from inside out: last registered wraps [tail],
    // first registered is outermost.
    SignalResult<Out> Function(In request) current = tail;
    for (final entry in entries.reversed) {
      final next = current;
      current = (In request) => entry.handler(request, next);
    }
    return current;
  }

  /// Clears all registered interceptors.
  void clear() {
    _entries.clear();
  }
}
