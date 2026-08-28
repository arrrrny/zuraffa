import 'package:nocterm/nocterm.dart' as nocterm;

/// A declarative UI tree node for a Zuraffa TUI screen.
///
/// [Screen] is the root abstraction every Zuraffa TUI developer starts from.
/// It adapts nocterm's [nocterm.StatelessComponent] so that:
///   * the public Zuraffa surface is independent of nocterm's API drift
///     (an upstream rename / signature change is a one-file fix here), and
///   * the type name matches the spec vocabulary (`Screen`, FR-002).
///
/// Subclasses implement [build] to declare their component tree.
///
/// ```dart
/// class HelloScreen extends Screen {
///   const HelloScreen();
///   @override
///   nocterm.Component build(nocterm.BuildContext context) =>
///     const nocterm.Text('Hello, Zuraffa TUI!');
/// }
/// ```
abstract class Screen extends nocterm.StatelessComponent {
  const Screen({super.key});
}
