import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// TDD tests for `FragmentBuilder<S>` (spec 038).
///
/// Cycle 2 covers the core granular-rebuild data path (U8, U9, U13, U17):
/// slice-scoped subscription, rebuild isolation, per-emission rebuilds, and
/// detached-fragment ignore semantics.
void main() {
  group('FragmentBuilder granular rebuilds (FR-002, SC-002)', () {
    test('a slice-A change rebuilds only fragment A [U8]', () {
      final manualA = _ManualUseCase<int>();
      final manualB = _ManualUseCase<int>();
      final sliceA = SignalSlice<int>(useCase: manualA, params: null);
      final sliceB = SignalSlice<int>(useCase: manualB, params: null);
      final host = WidgetHost(
        _TwoFragmentView(controller: null, sliceA: sliceA, sliceB: sliceB),
      );

      host.mount();
      // Eager initial delivery: both fragments processed one loading emission.
      expect(host.fragments.length, 2);
      final fragA = (host.fragments[0]) as FragmentBuilder<int>;
      final fragB = (host.fragments[1]) as FragmentBuilder<int>;
      final aInitial = fragA.rebuildCount;
      final bInitial = fragB.rebuildCount;
      expect(
        aInitial,
        1,
        reason: 'attach processes the eager initial emission',
      );
      expect(bInitial, 1);

      manualA.emit(10);

      expect(
        fragA.rebuildCount,
        aInitial + 1,
        reason: 'the bound fragment rebuilds exactly once',
      );
      expect(fragA.output, 'data:10');
      expect(
        fragB.rebuildCount,
        bInitial,
        reason: 'the sibling fragment is NOT rebuilt (SC-002)',
      );
      expect(fragB.output, isNull);

      manualB.emit(20);

      expect(fragB.rebuildCount, bInitial + 1);
      expect(fragB.output, 'data:20');
      expect(
        fragA.rebuildCount,
        aInitial + 1,
        reason: 'fragA must not rebuild for a slice-B change',
      );
      expect(
        host.buildCount,
        1,
        reason: 'the parent view shell never re-runs build (granular!)',
      );
    });

    test(
      'slices A and B changing in the same turn rebuild each exactly once [U9]',
      () {
        final manualA = _ManualUseCase<int>();
        final manualB = _ManualUseCase<int>();
        final sliceA = SignalSlice<int>(useCase: manualA, params: null);
        final sliceB = SignalSlice<int>(useCase: manualB, params: null);
        final host = WidgetHost(
          _TwoFragmentView(controller: null, sliceA: sliceA, sliceB: sliceB),
        );

        host.mount();
        final fragA = (host.fragments[0]) as FragmentBuilder<int>;
        final fragB = (host.fragments[1]) as FragmentBuilder<int>;
        final aInitial = fragA.rebuildCount;
        final bInitial = fragB.rebuildCount;

        // Same synchronous turn: A twice, B once.
        manualA.emit(1);
        manualA.emit(2);
        manualB.emit(3);

        expect(
          fragA.rebuildCount,
          aInitial + 2,
          reason: 'two A emissions -> two independent A rebuilds',
        );
        expect(fragA.output, 'data:2', reason: 'last emission wins');
        expect(fragB.rebuildCount, bInitial + 1);
        expect(fragB.output, 'data:3');
        expect(host.buildCount, 1);
      },
    );

    test('a data emission invokes builder with the slice value [U13]', () {
      final manual = _ManualUseCase<int>();
      final slice = SignalSlice<int>(useCase: manual, params: null);
      final (host, context) = _mountedHost();

      final fragment = context.attach(
        FragmentBuilder<int>(
          slice: slice,
          builder: (context, data) => 'value:$data',
        ),
      );

      manual.emit(42);

      expect(
        fragment.output,
        'value:42',
        reason:
            'builder receives the slice data and its return value '
            'becomes the fragment output',
      );
      expect(
        fragment.rebuildCount,
        2,
        reason: 'initial loading emission + one data emission',
      );
      host.unmount();
    });

    test('a detached fragment ignores subsequent slice emissions [U17]', () {
      final manual = _ManualUseCase<int>();
      final slice = SignalSlice<int>(useCase: manual, params: null);
      final (host, context) = _mountedHost();

      final fragment = context.attach(
        FragmentBuilder<int>(
          slice: slice,
          builder: (context, data) => 'value:$data',
        ),
      );
      manual.emit(1);
      expect(fragment.output, 'value:1');

      fragment.detach();
      manual.emit(2);

      expect(
        fragment.rebuildCount,
        2,
        reason: 'no rebuild cycles after detach',
      );
      expect(
        fragment.output,
        'value:1',
        reason:
            'output freezes at the last state — no state updates on a '
            'detached fragment (FR-008 in-flight async)',
      );
      host.unmount();
    });
  });

  _stateBuilderTests();
  _edgeCaseTests();
}

/// Mounts a minimal view and returns its host and live context.
(WidgetHost<_NilController>, ViewContext) _mountedHost() {
  final host = WidgetHost<_NilController>(
    _NilView(controller: _NilController()),
  );
  host.mount();
  return (host, host.context!);
}

class _NilController {}

class _NilView extends ControlledWidget<_NilController> {
  _NilView({required super.controller});
}

/// A use case whose result can be driven manually from the test.
class _ManualUseCase<T> extends ZuraffaUseCase<dynamic, T> {
  SignalResult<T>? _active;

  @override
  SignalResult<T> call(dynamic params, {ZuraffaContext? context}) {
    _active = SignalResult<T>.initial(LoadingResult<T, AppFailure>.loading());
    return _active!;
  }

  void emit(T value) => _active?.emitSuccess(value);

  /// Simulates a polymorphic response whose concrete type changed: the
  /// value cannot be delivered as T, so the pipeline converts it into a
  /// validation failure — the realistic "type mismatch" flow.
  void emitWrongType(Object wrongValue) => _active?.emitFailure(
    AppFailure.validation(
      'response type changed: expected $T, got ${wrongValue.runtimeType}',
    ),
  );

  void fail(String message) =>
      _active?.emitFailure(AppFailure.validation(message));

  void startLoading() => _active?.emitLoading();
}

class _TwoFragmentView extends ControlledWidget<Object?> {
  _TwoFragmentView({
    required super.controller,
    required this.sliceA,
    required this.sliceB,
  });

  final SignalSlice<int> sliceA;
  final SignalSlice<int> sliceB;

  @override
  Object? build(ViewContext context) {
    context.attach(
      FragmentBuilder<int>(
        slice: sliceA,
        builder: (context, data) => 'data:$data',
      ),
    );
    context.attach(
      FragmentBuilder<int>(
        slice: sliceB,
        builder: (context, data) => 'data:$data',
      ),
    );
    return null;
  }
}

/// Cycle 3: state builders (FR-003, US3) — onLoading/onError/onEmpty and the
/// state resolution rules. Appended after the cycle-2 data path went green.
void _stateBuilderTests() {
  group('FragmentBuilder state builders (FR-003)', () {
    test(
      'a loading slice renders onLoading — initially and on re-entry [U10]',
      () {
        final manual = _ManualUseCase<int>();
        final slice = SignalSlice<int>(useCase: manual, params: null);
        final (host, context) = _mountedHost();

        final fragment = context.attach(
          FragmentBuilder<int>(
            slice: slice,
            onLoading: (context) => 'loading',
            builder: (context, data) => 'data:$data',
          ),
        );

        expect(
          fragment.state,
          FragmentState.loading,
          reason: 'eager initial delivery resolves to loading',
        );
        expect(fragment.output, 'loading');

        manual.emit(7);
        expect(fragment.state, FragmentState.data);
        expect(fragment.output, 'data:7');

        manual.startLoading();
        expect(
          fragment.state,
          FragmentState.loading,
          reason: 're-entering loading renders onLoading again',
        );
        expect(fragment.output, 'loading');
        host.unmount();
      },
    );

    test('a failed slice renders onError with the AppFailure [U11]', () {
      final manual = _ManualUseCase<int>();
      final slice = SignalSlice<int>(useCase: manual, params: null);
      final (host, context) = _mountedHost();

      AppFailure? seenFailure;
      final fragment = context.attach(
        FragmentBuilder<int>(
          slice: slice,
          onError: (context, error) {
            seenFailure = error;
            return 'err:${error.message}';
          },
          builder: (context, data) => 'data:$data',
        ),
      );

      manual.fail('network down');

      expect(fragment.state, FragmentState.error);
      expect(fragment.output, 'err:network down');
      expect(
        seenFailure,
        isA<AppFailure>(),
        reason: 'the error builder receives the AppFailure',
      );
      expect(seenFailure!.message, 'network down');
      host.unmount();
    });

    test('null data and empty collections render onEmpty [U12]', () {
      // (a) successful null data
      final manualNull = _ManualUseCase<int?>();
      final nullSlice = SignalSlice<int?>(useCase: manualNull, params: null);
      final (host, context) = _mountedHost();

      final nullFragment = context.attach(
        FragmentBuilder<int?>(
          slice: nullSlice,
          onEmpty: (context) => 'empty',
          builder: (context, data) => 'data:$data',
        ),
      );
      manualNull.emit(null);
      expect(
        nullFragment.state,
        FragmentState.empty,
        reason: 'a success with null data is "no data" (FR-008 edge)',
      );
      expect(nullFragment.output, 'empty');

      // (b) empty list
      final manualList = _ManualUseCase<List<String>>();
      final listSlice = SignalSlice<List<String>>(
        useCase: manualList,
        params: null,
      );
      final listFragment = context.attach(
        FragmentBuilder<List<String>>(
          slice: listSlice,
          onEmpty: (context) => 'empty list',
          builder: (context, data) => 'data:${data.length}',
        ),
      );
      manualList.emit([]);
      expect(
        listFragment.state,
        FragmentState.empty,
        reason: 'an empty Iterable represents "no data"',
      );
      expect(listFragment.output, 'empty list');

      // (c) empty map and empty string
      final manualMap = _ManualUseCase<Map<String, int>>();
      final mapSlice = SignalSlice<Map<String, int>>(
        useCase: manualMap,
        params: null,
      );
      final mapFragment = context.attach(
        FragmentBuilder<Map<String, int>>(
          slice: mapSlice,
          onEmpty: (context) => 'empty map',
          builder: (context, data) => 'data',
        ),
      );
      manualMap.emit({});
      expect(mapFragment.state, FragmentState.empty);
      expect(mapFragment.output, 'empty map');

      final manualStr = _ManualUseCase<String>();
      final strSlice = SignalSlice<String>(useCase: manualStr, params: null);
      final strFragment = context.attach(
        FragmentBuilder<String>(
          slice: strSlice,
          onEmpty: (context) => 'empty string',
          builder: (context, data) => 'data:$data',
        ),
      );
      manualStr.emit('');
      expect(strFragment.state, FragmentState.empty);
      expect(strFragment.output, 'empty string');

      // (d) a NON-empty value is data, not empty
      manualList.emit(['a']);
      expect(
        listFragment.state,
        FragmentState.data,
        reason: 'boundary: one element is data, not empty',
      );
      expect(listFragment.output, 'data:1');
      host.unmount();
    });

    test(
      'omitted state builders render null output without crashing [U14]',
      () {
        final manual = _ManualUseCase<int>();
        final slice = SignalSlice<int>(useCase: manual, params: null);
        final (host, context) = _mountedHost();

        final fragment = context.attach(
          FragmentBuilder<int>(
            slice: slice,
            builder: (context, data) => 'data:$data',
          ),
        );

        // Loading with no onLoading: null output, no crash, no forced UI.
        expect(fragment.state, FragmentState.loading);
        expect(fragment.output, isNull);

        manual.fail('boom');
        expect(
          fragment.state,
          FragmentState.error,
          reason: 'state still resolves without the builder',
        );
        expect(
          fragment.output,
          isNull,
          reason: 'no forced error UI — the spec makes state builders opt-in',
        );

        expect(
          fragment.rebuildCount,
          2,
          reason: 'each emission is still exactly one rebuild cycle',
        );
        host.unmount();
      },
    );
  });
}

/// Cycle 4: FR-008 edge cases — runtime type mismatch, rapid successive
/// emissions, disposed slices, and independent loading/ready rendering.
/// The type guard and disposed-slice guard shipped with the cycle-3 state
/// machine, so these tests were born green; the verification phase proves
/// they are load-bearing via deliberate mutants (remove the guard -> red).
void _edgeCaseTests() {
  group('FragmentBuilder edge cases (FR-008)', () {
    test('a runtime type change surfaces as a clear error, no crash [U15]', () {
      // A polymorphic upstream: the use case succeeds with a well-typed
      // payload, then the response shape changes. Dart's reified generics
      // prevent an untyped value from reaching the builder callback, so the
      // realistic pipeline converts the mismatch into a Failure INSIDE the
      // use case — the fragment must surface it as the error state, never
      // crash (FR-008 "type changes" edge case).
      final manual = _ManualUseCase<Map<String, Object?>>();
      final slice = SignalSlice<Map<String, Object?>>(
        useCase: manual,
        params: null,
      );
      final (host, context) = _mountedHost();

      final fragment = context.attach(
        FragmentBuilder<Map<String, Object?>>(
          slice: slice,
          onError: (context, error) => 'err:${error.message}',
          builder: (context, data) => 'rows:${data.length}',
        ),
      );

      // First emission: a well-typed payload (data state).
      manual.emit({'kind': 'product', 'id': 1});
      expect(fragment.state, FragmentState.data);
      expect(fragment.output, 'rows:2');

      // The concrete type changes (polymorphic response): the upstream now
      // returns a List where a Map was expected, and the pipeline converts
      // the collision into a validation failure.
      manual.emitWrongType(['unexpected', 'list']);

      expect(
        fragment.state,
        FragmentState.error,
        reason: 'a type change resolves to the error state',
      );
      expect(
        fragment.output,
        contains('type'),
        reason: 'the failure is a clear, named error — not a crash',
      );
      expect(
        fragment.rebuildCount,
        3,
        reason: 'the mismatch consumed exactly one rebuild cycle',
      );
      host.unmount();
    });

    test('rapid successive emissions rebuild once per emission [U16]', () {
      final manual = _ManualUseCase<int>();
      final slice = SignalSlice<int>(useCase: manual, params: null);
      final (host, context) = _mountedHost();

      final fragment = context.attach(
        FragmentBuilder<int>(
          slice: slice,
          builder: (context, data) => 'v:$data',
        ),
      );
      final before = fragment.rebuildCount;

      manual.emit(1);
      manual.emit(2);
      manual.emit(3);

      expect(
        fragment.rebuildCount,
        before + 3,
        reason: 'deterministic: one rebuild per emission, no coalescing',
      );
      expect(fragment.output, 'v:3');
      host.unmount();
    });

    test('a slice disposed while attached ends the fragment cleanly [U18]', () {
      final manual = _ManualUseCase<int>();
      final slice = SignalSlice<int>(useCase: manual, params: null);
      final (host, context) = _mountedHost();

      final fragment = context.attach(
        FragmentBuilder<int>(
          slice: slice,
          builder: (context, data) => 'v:$data',
        ),
      );
      manual.emit(5);
      expect(fragment.output, 'v:5');

      slice.dispose(); // controller teardown while the fragment is attached

      expect(
        fragment.isAttached,
        isTrue,
        reason:
            'the fragment itself stays attached to the view; only the '
            'source went away',
      );
      expect(
        fragment.output,
        'v:5',
        reason: 'output freezes at the last state, no crash',
      );

      // A disposed source never emits again — nothing to observe, no errors.
      host.unmount();
      expect(fragment.isAttached, isFalse);
    });

    test('a loading slice does not block a ready slice [U19]', () {
      final manualLoading = _ManualUseCase<int>();
      final manualReady = _ManualUseCase<int>();
      final loadingSlice = SignalSlice<int>(
        useCase: manualLoading,
        params: null,
      );
      final readySlice = SignalSlice<int>(useCase: manualReady, params: null);
      final (host, context) = _mountedHost();

      final loadingFragment = context.attach(
        FragmentBuilder<int>(
          slice: loadingSlice,
          onLoading: (context) => 'still loading',
          builder: (context, data) => 'L:$data',
        ),
      );
      final readyFragment = context.attach(
        FragmentBuilder<int>(
          slice: readySlice,
          onLoading: (context) => 'loading',
          builder: (context, data) => 'R:$data',
        ),
      );

      manualReady.emit(99);

      expect(
        loadingFragment.state,
        FragmentState.loading,
        reason: 'the loading slice stays in loading state',
      );
      expect(loadingFragment.output, 'still loading');
      expect(
        readyFragment.state,
        FragmentState.data,
        reason: 'the ready slice renders data independently (FR-008)',
      );
      expect(readyFragment.output, 'R:99');
      host.unmount();
    });

    test(
      'attaching to an already-disposed slice stays inert, no crash [U18b]',
      () {
        final manual = _ManualUseCase<int>();
        final slice = SignalSlice<int>(useCase: manual, params: null);
        slice.dispose();
        final (host, context) = _mountedHost();

        late final FragmentBuilder<int> fragment;
        expect(
          () {
            fragment = context.attach(
              FragmentBuilder<int>(
                slice: slice,
                builder: (context, data) => 'v:$data',
              ),
            );
          },
          returnsNormally,
          reason:
              'a disposed source at attach time must not throw from the '
              'render path (FR-008)',
        );
        expect(
          fragment.rebuildCount,
          0,
          reason: 'no emissions processed — the fragment stays inert',
        );
        host.unmount();
      },
    );
  });
}
