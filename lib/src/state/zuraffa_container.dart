import 'zuraffa_ref.dart';
import 'provider_base.dart';

/// ZuraffaContainer - Manages provider instances and dependencies
///
/// The container is responsible for:
/// - Creating and caching provider values
/// - Managing the dependency graph
/// - Notifying listeners when providers change
/// - Disposing providers when no longer needed
///
/// Example:
/// ```dart
/// final container = ZuraffaContainer();
/// final product = container.read(productProvider);
/// ```
class ZuraffaContainer {
  final Map<String, dynamic> _cache = {};
  final Map<String, List<void Function()>> _listeners = {};
  final Map<String, ProviderBase> _providers = {};
  bool _disposed = false;

  /// Read a provider's value
  ///
  /// If the provider hasn't been created yet, it will be created and cached.
  /// Subsequent calls return the cached value.
  T read<T>(ProviderBase<T> provider) {
    if (_disposed) {
      throw StateError('Cannot read from disposed container');
    }

    // Check cache first
    if (_cache.containsKey(provider.id)) {
      return _cache[provider.id] as T;
    }

    // Create and cache
    final ref = ZuraffaRefImpl(this);
    final value = provider.create(ref);
    _cache[provider.id] = value;
    _providers[provider.id] = provider;

    return value;
  }

  /// Listen to provider changes
  ///
  /// The callback will be called whenever the provider is invalidated.
  void listen(ProviderBase provider, void Function() callback) {
    _listeners.putIfAbsent(provider.id, () => []).add(callback);
  }

  /// Remove a listener
  void unlisten(ProviderBase provider, void Function() callback) {
    _listeners[provider.id]?.remove(callback);
  }

  /// Invalidate a provider
  ///
  /// Clears the cached value and notifies all listeners.
  /// The provider will be recreated on next read.
  void invalidate(ProviderBase provider) {
    if (_disposed) {
      throw StateError('Cannot invalidate on disposed container');
    }

    // Remove from cache
    _cache.remove(provider.id);

    // Notify listeners
    final listeners = _listeners[provider.id];
    if (listeners != null) {
      for (final listener in List.from(listeners)) {
        listener();
      }
    }
  }

  /// Refresh a provider
  ///
  /// Forces the provider to recreate its value and notifies listeners.
  T refresh<T>(ProviderBase<T> provider) {
    invalidate(provider);
    return read(provider);
  }

  /// Check if a provider exists in the container
  bool exists(ProviderBase provider) {
    return _cache.containsKey(provider.id);
  }

  /// Dispose the container and all its providers
  ///
  /// After disposal, the container cannot be used.
  void dispose() {
    if (_disposed) return;

    // Dispose all notifier providers
    for (final entry in _providers.entries) {
      final provider = entry.value;
      if (provider is ZuraffaNotifierProvider) {
        provider.dispose();
      }
    }

    _cache.clear();
    _listeners.clear();
    _providers.clear();
    _disposed = true;
  }

  /// Check if container is disposed
  bool get disposed => _disposed;

  /// Get the number of cached providers
  int get size => _cache.length;

  /// Clear all cached values (but keep listeners)
  ///
  /// Useful for testing or forcing a full refresh
  void clearCache() {
    _cache.clear();
  }
}

/// Container with overrides for testing
///
/// Allows you to override specific providers for testing.
///
/// Example:
/// ```dart
/// final container = ZuraffaContainer.test(
///   overrides: [
///     productRepositoryProvider.overrideWith(mockRepository),
///   ],
/// );
/// ```
class ZuraffaContainerWithOverrides extends ZuraffaContainer {
  final List<ProviderOverride> _overrides;

  ZuraffaContainerWithOverrides({
    required List<ProviderOverride> overrides,
  }) : _overrides = overrides;

  @override
  T read<T>(ProviderBase<T> provider) {
    // Check for override
    for (final override in _overrides) {
      if (override.provider.id == provider.id) {
        return super.read(override.override as ProviderBase<T>);
      }
    }

    return super.read(provider);
  }

  /// Create a test container with overrides
  factory ZuraffaContainerWithOverrides.test({
    List<ProviderOverride> overrides = const [],
  }) {
    return ZuraffaContainerWithOverrides(overrides: overrides);
  }
}

/// Provider override for testing
class ProviderOverride<T> {
  final ProviderBase<T> provider;
  final ProviderBase<T> override;

  const ProviderOverride(this.provider, this.override);
}

/// Extension on ProviderBase for creating overrides
extension ProviderOverrideExtension<T> on ProviderBase<T> {
  ProviderOverride<T> overrideWith(T Function(ZuraffaRef ref) create) {
    return ProviderOverride(
      this,
      ZuraffaProvider<T, void>(
        (ref, _) => create(ref),
        id: '${id}_override',
      ),
    );
  }
}
