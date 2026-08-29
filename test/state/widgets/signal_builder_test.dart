import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// TDD tests for `SignalBuilder<T>` (spec 038, FR-004, US4) — the lightweight
/// UI-signal builder: rebuilds only when its bound [Signal] changes, separate
/// from domain-state [FragmentBuilder]s.
void main() {
  group('SignalBuilder granular rebuilds (FR-004, US4)', () {
    test('a signal change rebuilds only the bound builder [U20]', () {
      final editMode = Signal<bool>(false);
      final searchText = Signal<String>('');
      final slice = SignalSlice<int>(
        useCase: _ManualUseCase<int>(),
        params: null,
      );
      final host = WidgetHost(
        _MixedView(
          controller: null,
          editMode: editMode,
          searchText: searchText,
          slice: slice,
        ),
      );

      host.mount();
      expect(host.fragments.length, 3);
      final editFragment = host.fragments[0] as SignalBuilder<bool>;
      final searchFragment = host.fragments[1] as SignalBuilder<String>;
      final domainFragment = host.fragments[2] as FragmentBuilder<int>;

      final editInitial = editFragment.rebuildCount;
      final searchInitial = searchFragment.rebuildCount;
      final domainInitial = domainFragment.rebuildCount;
      expect(editInitial, 1, reason: 'eager initial delivery on attach');
      expect(editFragment.output, 'edit:false');

      editMode.value = true;

      expect(editFragment.rebuildCount, editInitial + 1);
      expect(editFragment.output, 'edit:true');
      expect(
        searchFragment.rebuildCount,
        searchInitial,
        reason: 'the other signal builder is NOT rebuilt',
      );
      expect(
        domainFragment.rebuildCount,
        domainInitial,
        reason:
            'a nearby domain FragmentBuilder is NOT rebuilt by a UI '
            'signal change (US4-S2)',
      );
      expect(host.buildCount, 1, reason: 'the view shell never re-runs');
      host.unmount();
    });

    test('a disposed signal renders the fallback without errors [U21]', () {
      final editMode = Signal<bool>(false);
      final host = WidgetHost<_Nil>(_NilView(controller: _Nil()));
      host.mount();

      final fragment = host.context!.attach(
        SignalBuilder<bool>(
          signal: editMode,
          fallback: (context) => 'gone',
          builder: (context, value) => 'edit:$value',
        ),
      );
      editMode.value = true;
      expect(fragment.output, 'edit:true');

      editMode.dispose();

      expect(
        fragment.output,
        'gone',
        reason: 'US4-S3: disposed signal renders the defined fallback',
      );
      expect(
        fragment.rebuildCount,
        2,
        reason: 'dispose is not an emission — no extra rebuild cycle',
      );
      host.unmount();
    });

    test(
      'attaching to an already-disposed signal stays inert, no crash [U21b]',
      () {
        final dead = Signal<int>(0);
        dead.dispose();
        final host = WidgetHost<_Nil>(_NilView(controller: _Nil()));
        host.mount();

        late final SignalBuilder<int> fragment;
        expect(
          () {
            fragment = host.context!.attach(
              SignalBuilder<int>(
                signal: dead,
                fallback: (context) => 'gone',
                builder: (context, value) => 'v:$value',
              ),
            );
          },
          returnsNormally,
          reason: 'a disposed signal at attach time must not throw (FR-008)',
        );
        expect(fragment.rebuildCount, 0, reason: 'no emissions processed');
        expect(
          fragment.output,
          'gone',
          reason: 'the fallback renders for a dead source',
        );
        host.unmount();
      },
    );

    test(
      'a nullable signal with null initial renders a defined default [U22]',
      () {
        // Signal<bool?> created without a meaningful initial value: the builder
        // receives null — deferred rendering — rather than crashing.
        final selectedTab = Signal<String?>(null);
        final host = WidgetHost<_Nil>(_NilView(controller: _Nil()));
        host.mount();

        final fragment = host.context!.attach(
          SignalBuilder<String?>(
            signal: selectedTab,
            builder: (context, value) => 'tab:${value ?? "none"}',
          ),
        );

        expect(
          fragment.rebuildCount,
          1,
          reason: 'the null initial value is delivered eagerly',
        );
        expect(
          fragment.output,
          'tab:none',
          reason: 'the builder handles null as a defined default',
        );

        selectedTab.value = 'home';
        expect(fragment.output, 'tab:home');
        host.unmount();
      },
    );
  });
}

class _Nil {}

class _NilView extends ControlledWidget<_Nil> {
  _NilView({required super.controller});
}

class _ManualUseCase<T> extends ZuraffaUseCase<dynamic, T> {
  SignalResult<T>? _active;

  @override
  SignalResult<T> call(dynamic params, {ZuraffaContext? context}) {
    _active = SignalResult<T>.initial(LoadingResult<T, AppFailure>.loading());
    return _active!;
  }

  void emit(T value) => _active?.emitSuccess(value);
}

class _MixedView extends ControlledWidget<Object?> {
  _MixedView({
    required super.controller,
    required this.editMode,
    required this.searchText,
    required this.slice,
  });

  final Signal<bool> editMode;
  final Signal<String> searchText;
  final SignalSlice<int> slice;

  @override
  Object? build(ViewContext context) {
    context.attach(
      SignalBuilder<bool>(
        signal: editMode,
        builder: (context, value) => 'edit:$value',
      ),
    );
    context.attach(
      SignalBuilder<String>(
        signal: searchText,
        builder: (context, value) => 'q:$value',
      ),
    );
    context.attach(
      FragmentBuilder<int>(
        slice: slice,
        builder: (context, data) => 'data:$data',
      ),
    );
    return null;
  }
}
