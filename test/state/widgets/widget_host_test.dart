import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Cycle 1 tests for the WidgetHost / ViewContext / FragmentContextError
/// mount layer (spec 038, behaviors U1..U5).
///
/// The mount layer is the "framework" that invokes ControlledWidget lifecycle
/// hooks and tracks attached fragments so rebuilds stay granular.
void main() {
  group('WidgetHost lifecycle', () {
    test('mount() invokes onInit exactly once and build exactly once [U1]', () {
      final controller = _LifecycleController();
      final view = _LifecycleView(controller: controller);
      final host = WidgetHost(view);

      expect(host.isMounted, isFalse);

      host.mount();

      expect(
        view.initCount,
        1,
        reason: 'onInit must fire exactly once on mount',
      );
      expect(
        view.buildCount,
        1,
        reason: 'build must run exactly once on mount',
      );
      expect(host.isMounted, isTrue);
      expect(host.buildCount, 1);

      // A second mount() is a no-op: lifecycle hooks fire exactly once.
      host.mount();
      expect(
        view.initCount,
        1,
        reason: 'second mount() must not re-fire onInit',
      );
      expect(
        view.buildCount,
        1,
        reason: 'second mount() must not re-run build',
      );
    });

    test('controller is non-null and identical inside onInit [U2]', () {
      final controller = _LifecycleController();
      final view = _LifecycleView(controller: controller);
      final host = WidgetHost(view);

      expect(
        view.controllerSeenInInit,
        isNull,
        reason: 'precondition: onInit has not run yet',
      );

      host.mount();

      expect(
        view.controllerSeenInInit,
        same(controller),
        reason:
            'FR-007: the typed controller must be available '
            'before/during onInit',
      );
      expect(host.widget.controller, same(controller));
      expect(controller.initCalls, 1);
    });

    test(
      'unmount() invokes onDispose exactly once; second unmount no-op [U3]',
      () {
        final controller = _LifecycleController();
        final view = _LifecycleView(controller: controller);
        final host = WidgetHost(view);

        host.mount();
        host.unmount();

        expect(
          view.disposeCount,
          1,
          reason: 'onDispose must fire exactly once on unmount',
        );
        expect(host.isMounted, isFalse);
        expect(
          host.context,
          isNull,
          reason: 'context is released after unmount',
        );

        host.unmount();
        expect(
          view.disposeCount,
          1,
          reason: 'a second unmount() must not re-fire onDispose',
        );
      },
    );
  });

  group('Fragment context requirement (FR-008: outside ControlledWidget)', () {
    test(
      'attaching to a detached context throws FragmentContextError [U4]',
      () {
        final controller = _LifecycleController();
        final view = _LifecycleView(controller: controller);
        final host = WidgetHost(view);

        host.mount();
        final context = view.lastContext!;
        expect(context.isAttached, isTrue);

        final fragment = _FakeFragment();
        context.attach(fragment);
        expect(fragment.isAttached, isTrue);

        host.unmount();
        expect(
          context.isAttached,
          isFalse,
          reason: 'context detaches with host',
        );

        final orphan = _FakeFragment();
        expect(
          () => context.attach(orphan),
          throwsA(
            isA<FragmentContextError>().having(
              (e) => e.message,
              'message',
              allOf(contains('ControlledWidget'), contains('mount')),
            ),
          ),
          reason:
              'FR-008: clear, actionable error — not a silent no-op, '
              'not an unrelated runtime exception',
        );
        expect(
          orphan.isAttached,
          isFalse,
          reason: 'the rejected fragment must stay detached',
        );
      },
    );

    test('unmount() detaches every attached fragment [U5]', () {
      final controller = _LifecycleController();
      final view = _LifecycleView(controller: controller);
      final host = WidgetHost(view);
      host.mount();

      final a = _FakeFragment();
      final b = _FakeFragment();
      view.lastContext!.attach(a);
      view.lastContext!.attach(b);
      expect(host.fragments.length, 2);

      host.unmount();

      expect(a.isAttached, isFalse, reason: 'all fragments detach on unmount');
      expect(b.isAttached, isFalse);
      expect(host.fragments, isEmpty);
      expect(a.detachCalls, 1, reason: 'detach hook ran exactly once');
      expect(b.detachCalls, 1);
      expect(
        view.disposeCount,
        1,
        reason: 'onDispose still fires exactly once after fragment teardown',
      );
    });
  });
}

class _LifecycleController {
  int initCalls = 0;
  int disposeCalls = 0;
}

class _LifecycleView extends ControlledWidget<_LifecycleController> {
  _LifecycleView({required super.controller});

  int initCount = 0;
  int disposeCount = 0;
  int buildCount = 0;
  _LifecycleController? controllerSeenInInit;
  ViewContext? lastContext;

  @override
  void onInit() {
    initCount++;
    controllerSeenInInit = controller; // typed access, no cast (FR-007)
    controller.initCalls++;
  }

  @override
  void onDispose() {
    disposeCount++;
    controller.disposeCalls++;
  }

  @override
  Object? build(ViewContext context) {
    buildCount++;
    lastContext = context;
    return 'built';
  }
}

class _FakeFragment extends ViewFragment {
  int detachCalls = 0;

  @override
  void onAttach() {}

  @override
  void onDetach() => detachCalls++;
}
