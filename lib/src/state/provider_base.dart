import 'zuraffa_ref.dart';
import 'zuraffa_notifier.dart';

/// Base class for all providers
///
/// Providers are the building blocks of Zuraffa state management.
/// They provide values that can be accessed via ref.read() or ref.watch().
abstract class ProviderBase<T> {
  /// Unique identifier for this provider
  final String id;

  /// Name for debugging
  final String? name;

  const ProviderBase({required this.id, this.name});

  /// Create the value for this provider
  ///
  /// Called by the container when the provider is first accessed
  T create(ZuraffaRef ref);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderBase && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name ?? 'Provider($id)';
}

/// Simple provider for values that don't change
///
/// Example:
/// ```dart
/// final apiBaseUrlProvider = ZuraffaProvider<String, void>(
///   (_) => 'https://api.example.com',
///   id: 'apiBaseUrl',
/// );
/// ```
class ZuraffaProvider<T, P> extends ProviderBase<T> {
  final T Function(ZuraffaRef ref, P? param) _create;
  final P? _param;

  ZuraffaProvider(
    this._create, {
    required String id,
    String? name,
    P? param,
  })  : _param = param,
        super(id: id, name: name);

  @override
  T create(ZuraffaRef ref) => _create(ref, _param);
}

/// Future provider for async operations
///
/// Example:
/// ```dart
/// final productProvider = ZuraffaFutureProvider<Product, String>(
///   (ref, id) async {
///     final repo = ref.read(productRepositoryProvider);
///     return await repo.getById(id);
///   },
///   id: 'product',
///   param: 'prod-123',
/// );
/// ```
class ZuraffaFutureProvider<T, P> extends ProviderBase<Future<T>> {
  final Future<T> Function(ZuraffaRef ref, P? param) _create;
  final P? _param;

  ZuraffaFutureProvider(
    this._create, {
    required String id,
    String? name,
    P? param,
  })  : _param = param,
        super(id: id, name: name);

  @override
  Future<T> create(ZuraffaRef ref) => _create(ref, _param);
}

/// Notifier provider for stateful logic
///
/// Example:
/// ```dart
/// final counterProvider = ZuraffaNotifierProvider<CounterNotifier, int>(
///   () => CounterNotifier(),
///   id: 'counter',
/// );
/// ```
class ZuraffaNotifierProvider<N extends ZuraffaNotifier<T>, T>
    extends ProviderBase<T> {
  final N Function() _createNotifier;
  N? _notifier;

  ZuraffaNotifierProvider(
    this._createNotifier, {
    required String id,
    String? name,
  }) : super(id: id, name: name);

  @override
  T create(ZuraffaRef ref) {
    _notifier = _createNotifier();
    _notifier!.initialize(ref);
    return _notifier!.state;
  }

  /// Get the notifier instance (for calling methods)
  N getNotifier(ZuraffaRef ref) {
    if (_notifier == null) {
      throw StateError('Notifier not initialized. Read the provider first.');
    }
    return _notifier!;
  }

  /// Dispose the notifier
  void dispose() {
    _notifier?.dispose();
    _notifier = null;
  }
}

/// Provider family - create providers with parameters
///
/// Example:
/// ```dart
/// final productFamily = ZuraffaProviderFamily<Product, String>(
///   (ref, id) async {
///     final repo = ref.read(productRepositoryProvider);
///     return await repo.getById(id);
///   },
/// );
///
/// // Use with parameter
/// final product = ref.watch(productFamily('prod-123'));
/// ```
class ZuraffaProviderFamily<T, P> {
  final Future<T> Function(ZuraffaRef ref, P param) _create;
  final Map<P, ZuraffaFutureProvider<T, P>> _instances = {};

  ZuraffaProviderFamily(this._create);

  ZuraffaFutureProvider<T, P> call(P param) {
    return _instances.putIfAbsent(
      param,
      () => ZuraffaFutureProvider<T, P>(
        _create,
        id: 'family_${param.hashCode}',
        param: param,
      ),
    );
  }

  /// Clear all cached instances
  void clear() {
    _instances.clear();
  }
}
