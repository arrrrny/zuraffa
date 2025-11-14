/// ZuraffaRef - The reference to the provider container
///
/// Provides access to providers and their state within ZuraffaWidget
///
/// Example:
/// ```dart
/// class MyWidget extends ZuraffaWidget {
///   @override
///   Widget build(BuildContext context, ZuraffaRef ref) {
///     final product = ref.watch(getProductProvider('123'));
///     return Text(product.name);
///   }
/// }
/// ```
abstract class ZuraffaRef {
  /// Read a provider once without subscribing to changes
  ///
  /// Use this when you want to access a provider's value without
  /// rebuilding when it changes (e.g., in event handlers)
  ///
  /// Example:
  /// ```dart
  /// onPressed: () {
  ///   final repo = ref.read(productRepositoryProvider);
  ///   repo.save(product);
  /// }
  /// ```
  T read<T>(ProviderBase<T> provider);

  /// Watch a provider and rebuild when it changes
  ///
  /// Use this in your build method to subscribe to provider changes.
  /// The widget will automatically rebuild when the provider's value changes.
  ///
  /// Example:
  /// ```dart
  /// final count = ref.watch(counterProvider);
  /// ```
  T watch<T>(ProviderBase<T> provider);

  /// Check if the ref is still mounted (not disposed)
  ///
  /// Use this to prevent state updates after async operations
  /// when the widget/provider might have been disposed.
  ///
  /// Example:
  /// ```dart
  /// Future<void> loadData() async {
  ///   final data = await api.fetch();
  ///   if (!ref.mounted) return; // Don't update if disposed
  ///   state = data;
  /// }
  /// ```
  bool get mounted;

  /// Invalidate a provider, forcing it to rebuild
  ///
  /// This clears the provider's cached value and triggers
  /// a rebuild for all listeners.
  ///
  /// Example:
  /// ```dart
  /// ref.invalidate(productsProvider); // Refresh the list
  /// ```
  void invalidate(ProviderBase provider);
}

/// Internal implementation of ZuraffaRef
///
/// This is used by ZuraffaScope and ZuraffaWidget to provide
/// access to the container.
class ZuraffaRefImpl implements ZuraffaRef {
  final ZuraffaContainer _container;
  final Set<ProviderBase> _watchedProviders = {};
  bool _mounted = true;

  ZuraffaRefImpl(this._container);

  @override
  T read<T>(ProviderBase<T> provider) {
    if (!_mounted) {
      throw StateError('Cannot read from a disposed ref');
    }
    return _container.read(provider);
  }

  @override
  T watch<T>(ProviderBase<T> provider) {
    if (!_mounted) {
      throw StateError('Cannot watch from a disposed ref');
    }
    _watchedProviders.add(provider);
    return _container.read(provider);
  }

  @override
  bool get mounted => _mounted;

  @override
  void invalidate(ProviderBase provider) {
    if (!_mounted) {
      throw StateError('Cannot invalidate from a disposed ref');
    }
    _container.invalidate(provider);
  }

  /// Dispose this ref (called by framework)
  void dispose() {
    _mounted = false;
    _watchedProviders.clear();
  }

  /// Get all providers this ref is watching
  Set<ProviderBase> get watchedProviders => Set.unmodifiable(_watchedProviders);
}

/// Forward declaration - will be implemented in zuraffa_container.dart
abstract class ZuraffaContainer {
  T read<T>(ProviderBase<T> provider);
  void invalidate(ProviderBase provider);
}

/// Forward declaration - will be implemented in provider_base.dart
abstract class ProviderBase<T> {
  String get id;
}
