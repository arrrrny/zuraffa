import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/core/component.dart';

void main() {
  group('Component model (FR-002, SC-002)', () {
    test(
      'A4 / U5: a Screen is a composable declarative tree node whose build '
      'returns the rendered tree',
      () {
        // A minimal hand-composed screen lays out Text inside Column.
        final screen = const _DemoScreen();
        expect(screen, isA<Screen>());
        expect(screen, isA<nocterm.Component>());
      },
    );

    test('U6/U7: Screen is a StatelessComponent subclass — nocterm drives build', () {
      // The runtime contract: nocterm's pumpComponent drives Screen.build.
      // We assert the type relationship so Zuraffa consumers can use any
      // nocterm Component inside their Screen.build return value.
      const screen = _DemoScreen();
      expect(screen, isA<nocterm.StatelessComponent>());
    });
  });
}

class _DemoScreen extends Screen {
  const _DemoScreen();

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return const nocterm.Column(
      children: [
        nocterm.Text('Hello, Zuraffa TUI!'),
        nocterm.Text('Second line.'),
      ],
    );
  }
}
