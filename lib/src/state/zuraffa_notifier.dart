import 'zuraffa_ref.dart';

/// ZuraffaNotifier - Base class for stateful providers
///
/// Manages state with lifecycle safety and automatic rebuilds.
/// Subclass this to create stateful logic.
///
/// Example:
/// ```dart
/// @zuraffa
/// class CounterNotifier extends ZuraffaNotifier<int> {
///   @override
///   int build() => 0;
///
///   void increment() {
///     state = state + 1;
///   }
///
///   Future<void> incrementAsync() async {
///     await Future.delayed(Duration(seconds: 1));
///     if (!ref.mounted) return; // Safety check!
///     state = state + 1;
///   }
/// }
/// ```
abstract class ZuraffaNotifier<T> {
  late ZuraffaRef _ref;
  late T _state;
  bool _initialized = false;
  bool _disposed = false;

  final List<void Function(T)> _listeners = [];

  /// Access to the ref for reading other providers
  ZuraffaRef get ref => _ref;

  /// Current state value
  T get state {
    if (!_initialized) {
      throw StateError('Notifier not initialized. Call build() first.');
    }
    return _state;
  }

  /// Update the state and notify listeners
  ///
  /// This will trigger rebuilds for all widgets watching this provider.
  ///
  /// Always check ref.mounted before updating state after async operations!
  set state(T newState) {
    if (_disposed) {
      throw StateError('Cannot update state of disposed notifier');
    }

    if (!_initialized) {
      throw StateError('Notifier not initialized. Call build() first.');
    }

    if (_state == newState) {
      return; // No change, skip notification
    }

    _state = newState;
    _notifyListeners();
  }

  /// Initialize the notifier (called by framework)
  ///
  /// Returns the initial state. Override this to provide your initial state.
  T build();

  /// Internal: Initialize with ref
  void initialize(ZuraffaRef ref) {
    if (_initialized) {
      throw StateError('Notifier already initialized');
    }

    _ref = ref;
    _state = build();
    _initialized = true;
  }

  /// Add a listener that will be called when state changes
  void addListener(void Function(T) listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(void Function(T) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of state change
  void _notifyListeners() {
    for (final listener in List.from(_listeners)) {
      listener(_state);
    }
  }

  /// Dispose this notifier (called by framework)
  ///
  /// Override this to cleanup resources (timers, streams, etc.)
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _listeners.clear();
  }

  /// Check if notifier is disposed
  bool get disposed => _disposed;
}

/// StreamNotifier - Notifier for stream-based state
///
/// Automatically listens to a stream and updates state.
///
/// Example:
/// ```dart
/// @zuraffa
/// class MessagesNotifier extends StreamZuraffaNotifier<List<Message>> {
///   @override
///   Stream<List<Message>> build() {
///     return messageRepository.watchMessages();
///   }
/// }
/// ```
abstract class StreamZuraffaNotifier<T> extends ZuraffaNotifier<AsyncValue<T>> {
  StreamSubscription<T>? _subscription;

  @override
  AsyncValue<T> build() {
    final stream = buildStream();

    // Start with loading state
    state = AsyncValue.loading();

    // Subscribe to stream
    _subscription = stream.listen(
      (data) {
        if (!ref.mounted) return;
        state = AsyncValue.data(data);
      },
      onError: (error, stackTrace) {
        if (!ref.mounted) return;
        state = AsyncValue.error(error, stackTrace);
      },
    );

    return state;
  }

  /// Build the stream to watch
  Stream<T> buildStream();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// AsyncValue - Represents async state (loading/data/error)
///
/// Similar to AsyncValue in Riverpod
sealed class AsyncValue<T> {
  const AsyncValue();

  factory AsyncValue.loading() = AsyncLoading;
  factory AsyncValue.data(T data) = AsyncData;
  factory AsyncValue.error(Object error, StackTrace stackTrace) = AsyncError;

  /// Pattern match on the async value
  R when<R>({
    required R Function() loading,
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return switch (this) {
      AsyncLoading() => loading(),
      AsyncData(:final value) => data(value),
      AsyncError(:final error, :final stackTrace) => error(error, stackTrace),
    };
  }
}

class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading();
}

class AsyncData<T> extends AsyncValue<T> {
  final T value;
  const AsyncData(this.value);
}

class AsyncError<T> extends AsyncValue<T> {
  final Object error;
  final StackTrace stackTrace;
  const AsyncError(this.error, this.stackTrace);
}

// Forward declaration for StreamSubscription
import 'dart:async';
