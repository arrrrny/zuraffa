import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('AsyncSlice<T>', () {
    test('idle() builds an AsyncSliceIdle with no data', () {
      final slice = AsyncSlice<int>.idle();
      expect(slice, isA<AsyncSliceIdle<int>>());
    });

    test('loading() builds an AsyncSliceLoading', () {
      final slice = AsyncSlice<String>.loading();
      expect(slice, isA<AsyncSliceLoading<String>>());
    });

    test('ready(data) carries data and defaults isRefreshing to false', () {
      final slice = AsyncSlice<int>.ready(42);
      expect(slice, isA<AsyncSliceReady<int>>());
      final ready = slice as AsyncSliceReady<int>;
      expect(ready.data, 42);
      expect(ready.isRefreshing, isFalse);
    });

    test('ready(data, isRefreshing: true) marks a background refresh', () {
      final slice = AsyncSlice<int>.ready(7, isRefreshing: true);
      final ready = slice as AsyncSliceReady<int>;
      expect(ready.data, 7);
      expect(ready.isRefreshing, isTrue);
    });

    test('failed(failure) carries the failure with no stale data', () {
      final slice = AsyncSlice<int>.failed(AppFailure.network(message: 'boom'));
      expect(slice, isA<AsyncSliceFailed<int>>());
      final failed = slice as AsyncSliceFailed<int>;
      expect(failed.appFailure, isA<NetworkFailure>());
      expect(failed.appFailure.message, 'boom');
      expect(failed.staleData, isNull);
    });

    test('failed(failure, staleData: x) keeps the last known value', () {
      final slice = AsyncSlice<int>.failed(
        AppFailure.timeout(message: 'slow'),
        staleData: 99,
      );
      final failed = slice as AsyncSliceFailed<int>;
      expect(failed.appFailure, isA<TimeoutFailure>());
      expect(failed.staleData, 99);
    });

    group('when matcher', () {
      test('dispatches every variant to its callback', () {
        String label(AsyncSlice<int> slice) => slice.when<String>(
          asyncSliceIdle: (_) => 'idle',
          asyncSliceLoading: (_) => 'loading',
          asyncSliceReady: (s) => 'ready:${s.data}',
          asyncSliceFailed: (s) => 'failed:${s.appFailure.message}',
        );

        expect(label(AsyncSlice<int>.idle()), 'idle');
        expect(label(AsyncSlice<int>.loading()), 'loading');
        expect(label(AsyncSlice<int>.ready(5)), 'ready:5');
        expect(
          label(AsyncSlice<int>.failed(AppFailure.network(message: 'x'))),
          'failed:x',
        );
      });

      test('maybeWhen falls back to orElse for an unmatched variant', () {
        final slice = AsyncSlice<int>.ready(1);
        final value = slice.maybeWhen<String>(
          asyncSliceReady: (s) => 'ready:${s.data}',
          orElse: () => 'other',
        );
        expect(value, 'ready:1');
      });
    });
  });

  group('ZfaFeatureState', () {
    late _TestFeatureState state;

    setUp(() => state = _TestFeatureState());

    test('bind + slice round-trips a typed AsyncSlice by id', () {
      state.bind('sku-1', AsyncSlice<int>.ready(10));
      final slice = state.slice<int>('sku-1');
      expect(slice, isNotNull);
      expect((slice! as AsyncSliceReady<int>).data, 10);
    });

    test('ids lists every bound principal key', () {
      state.bind('a', AsyncSlice<int>.idle());
      state.bind('b', AsyncSlice<int>.loading());
      expect(state.ids, {'a', 'b'});
    });

    test('contains reports presence and unbind removes', () {
      state.bind('x', AsyncSlice<int>.idle());
      expect(state.contains('x'), isTrue);
      final removed = state.unbind('x');
      expect(removed, isA<AsyncSliceIdle<int>>());
      expect(state.contains('x'), isFalse);
      expect(state.slice<int>('x'), isNull);
    });

    test('slice<T> throws when the bound slice has the wrong type', () {
      state.bind('n', AsyncSlice<int>.ready(1));
      expect(() => state.slice<String>('n'), throwsStateError);
    });

    test('dispose drops every slice', () {
      state.bind('a', AsyncSlice<int>.idle());
      state.bind('b', AsyncSlice<int>.idle());
      state.dispose();
      expect(state.ids, isEmpty);
    });
  });
}

class _TestFeatureState extends ZfaFeatureState {
  _TestFeatureState();
}
