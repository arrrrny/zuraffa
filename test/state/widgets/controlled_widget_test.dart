import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Cycle 1 tests for the `ControlledWidget<C>` base class
/// (spec 038, behaviors U6..U7).
void main() {
  group('ControlledWidget typed controller access', () {
    test('subclass reads the controller with static type C, no cast [U6]', () {
      final controller = _DemoController(title: 'products');
      final view = _DemoView(controller: controller);
      final host = WidgetHost(view);

      host.mount();

      // The typed field read below compiles without any cast; onInit recorded
      // the value it saw through the same typed access.
      expect(
        view.titleSeenInInit,
        'products',
        reason:
            'controller is typed as _DemoController inside lifecycle '
            'hooks and build',
      );
      expect(host.widget.controller.title, 'products');
      expect(host.widget.controller, isA<_DemoController>());
    });

    test(
      'default hooks are no-ops — bare subclass mounts and unmounts [U7]',
      () {
        final view = _BareView(controller: _DemoController(title: 'x'));
        final host = WidgetHost(view);

        // No overrides of onInit/onDispose: mount/unmount must not throw.
        host.mount();
        expect(host.isMounted, isTrue);
        expect(
          host.buildCount,
          1,
          reason: 'build still runs once even with default hooks',
        );

        host.unmount();
        expect(host.isMounted, isFalse);
      },
    );
  });
}

class _DemoController {
  _DemoController({required this.title});
  final String title;
}

class _DemoView extends ControlledWidget<_DemoController> {
  _DemoView({required super.controller});

  String? titleSeenInInit;

  @override
  void onInit() {
    // Static type check: `controller.title` resolves against _DemoController.
    titleSeenInInit = controller.title;
  }

  @override
  Object? build(ViewContext context) => controller.title;
}

class _BareView extends ControlledWidget<_DemoController> {
  _BareView({required super.controller});
}
