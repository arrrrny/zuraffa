part of 'async_slice.dart';

// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

sealed class AsyncSlice<T> implements ZorphyUnionBase {
  const AsyncSlice();

  factory AsyncSlice.idle() => AsyncSliceIdle<T>.fromTrusted();

  factory AsyncSlice.loading() => AsyncSliceLoading<T>.fromTrusted();

  factory AsyncSlice.ready(T data, {bool isRefreshing = false}) =>
      AsyncSliceReady<T>.fromTrusted(data: data, isRefreshing: isRefreshing);

  factory AsyncSlice.failed(Object? failure, {Object? staleData}) =>
      AsyncSliceFailed<T>.fromTrusted(failure: failure, staleData: staleData);
}

final class AsyncSliceIdle<T> extends AsyncSlice<T> implements ZorphyValueBase {
  const AsyncSliceIdle.fromTrusted();

  const AsyncSliceIdle();

  AsyncSliceIdle<T> copyWith() {
    return AsyncSliceIdle<T>.fromTrusted();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncSliceIdle;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AsyncSliceIdle';
}

final class AsyncSliceLoading<T> extends AsyncSlice<T>
    implements ZorphyValueBase {
  const AsyncSliceLoading.fromTrusted();

  const AsyncSliceLoading();

  AsyncSliceLoading<T> copyWith() {
    return AsyncSliceLoading<T>.fromTrusted();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncSliceLoading;
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AsyncSliceLoading';
}

final class AsyncSliceReady<T> extends AsyncSlice<T>
    implements ZorphyValueBase {
  const AsyncSliceReady.fromTrusted({
    required this.data,
    required this.isRefreshing,
  });

  final T data;

  final bool isRefreshing;

  AsyncSliceReady<T> copyWith({T? data, bool? isRefreshing}) {
    return AsyncSliceReady<T>.fromTrusted(
      data: data ?? this.data,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncSliceReady &&
        ZorphyCollections.equals(this.data, other.data) &&
        this.isRefreshing == other.isRefreshing;
  }

  @override
  int get hashCode =>
      Object.hashAll([ZorphyCollections.hash(data), isRefreshing]);

  @override
  String toString() =>
      'AsyncSliceReady(data: $data, isRefreshing: $isRefreshing)';
}

final class AsyncSliceFailed<T> extends AsyncSlice<T>
    implements ZorphyValueBase {
  const AsyncSliceFailed.fromTrusted({this.failure, this.staleData});

  final Object? failure;

  final Object? staleData;

  AsyncSliceFailed<T> copyWith({
    Object? failure = _sentinel,
    Object? staleData = _sentinel,
  }) {
    return AsyncSliceFailed<T>.fromTrusted(
      failure: identical(failure, _sentinel)
          ? this.failure
          : failure as Object?,
      staleData: identical(staleData, _sentinel)
          ? this.staleData
          : staleData as Object?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AsyncSliceFailed &&
        this.failure == other.failure &&
        this.staleData == other.staleData;
  }

  @override
  int get hashCode => Object.hashAll([failure, staleData]);

  @override
  String toString() =>
      'AsyncSliceFailed(failure: $failure, staleData: $staleData)';
}

extension AsyncSliceWhenE<T> on AsyncSlice<T> {
  TResult when<TResult>({
    required TResult Function(AsyncSliceIdle<T>) asyncSliceIdle,
    required TResult Function(AsyncSliceLoading<T>) asyncSliceLoading,
    required TResult Function(AsyncSliceReady<T>) asyncSliceReady,
    required TResult Function(AsyncSliceFailed<T>) asyncSliceFailed,
  }) {
    return switch (this) {
      AsyncSliceIdle<T> value => asyncSliceIdle(value),
      AsyncSliceLoading<T> value => asyncSliceLoading(value),
      AsyncSliceReady<T> value => asyncSliceReady(value),
      AsyncSliceFailed<T> value => asyncSliceFailed(value),
    };
  }

  TResult maybeWhen<TResult>({
    TResult Function(AsyncSliceIdle<T>)? asyncSliceIdle,
    TResult Function(AsyncSliceLoading<T>)? asyncSliceLoading,
    TResult Function(AsyncSliceReady<T>)? asyncSliceReady,
    TResult Function(AsyncSliceFailed<T>)? asyncSliceFailed,
    required TResult Function() orElse,
  }) {
    final self = this;
    if (self is AsyncSliceIdle<T>) {
      final callback = asyncSliceIdle;
      return callback == null ? orElse() : callback(self);
    }
    if (self is AsyncSliceLoading<T>) {
      final callback = asyncSliceLoading;
      return callback == null ? orElse() : callback(self);
    }
    if (self is AsyncSliceReady<T>) {
      final callback = asyncSliceReady;
      return callback == null ? orElse() : callback(self);
    }
    if (self is AsyncSliceFailed<T>) {
      final callback = asyncSliceFailed;
      return callback == null ? orElse() : callback(self);
    }
    return orElse();
  }
}

extension AsyncSliceIdleMorphing<T> on AsyncSliceIdle<T> {
  AsyncSliceLoading<T> changeToAsyncSliceLoading() {
    return AsyncSliceLoading<T>.fromTrusted();
  }

  AsyncSliceReady<T> changeToAsyncSliceReady({
    required T data,
    required bool isRefreshing,
  }) {
    return AsyncSliceReady<T>.fromTrusted(
      data: data,
      isRefreshing: isRefreshing,
    );
  }

  AsyncSliceFailed<T> changeToAsyncSliceFailed({
    Object? failure,
    Object? staleData,
  }) {
    return AsyncSliceFailed<T>.fromTrusted(
      failure: failure,
      staleData: staleData,
    );
  }
}

extension AsyncSliceLoadingMorphing<T> on AsyncSliceLoading<T> {
  AsyncSliceIdle<T> changeToAsyncSliceIdle() {
    return AsyncSliceIdle<T>.fromTrusted();
  }

  AsyncSliceReady<T> changeToAsyncSliceReady({
    required T data,
    required bool isRefreshing,
  }) {
    return AsyncSliceReady<T>.fromTrusted(
      data: data,
      isRefreshing: isRefreshing,
    );
  }

  AsyncSliceFailed<T> changeToAsyncSliceFailed({
    Object? failure,
    Object? staleData,
  }) {
    return AsyncSliceFailed<T>.fromTrusted(
      failure: failure,
      staleData: staleData,
    );
  }
}

extension AsyncSliceReadyMorphing<T> on AsyncSliceReady<T> {
  AsyncSliceIdle<T> changeToAsyncSliceIdle() {
    return AsyncSliceIdle<T>.fromTrusted();
  }

  AsyncSliceLoading<T> changeToAsyncSliceLoading() {
    return AsyncSliceLoading<T>.fromTrusted();
  }

  AsyncSliceFailed<T> changeToAsyncSliceFailed({
    Object? failure,
    Object? staleData,
  }) {
    return AsyncSliceFailed<T>.fromTrusted(
      failure: failure,
      staleData: staleData,
    );
  }
}

extension AsyncSliceFailedMorphing<T> on AsyncSliceFailed<T> {
  AsyncSliceIdle<T> changeToAsyncSliceIdle() {
    return AsyncSliceIdle<T>.fromTrusted();
  }

  AsyncSliceLoading<T> changeToAsyncSliceLoading() {
    return AsyncSliceLoading<T>.fromTrusted();
  }

  AsyncSliceReady<T> changeToAsyncSliceReady({
    required T data,
    required bool isRefreshing,
  }) {
    return AsyncSliceReady<T>.fromTrusted(
      data: data,
      isRefreshing: isRefreshing,
    );
  }
}
