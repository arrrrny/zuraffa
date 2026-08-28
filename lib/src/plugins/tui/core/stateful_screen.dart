/// Stateful screen mechanism for Zuraffa TUIs (FR-003).
///
/// Adapts nocterm's [nocterm.StatefulComponent] + [nocterm.State] so Zuraffa
/// TUI developers get a familiar `setState(() { ... })` re-render contract
/// without touching nocterm internals directly.
///
/// Subclasses:
///   1. Declare a `StatefulScreen` subclass (the immutable configuration).
///   2. Declare a `TuiScreenState` subclass holding the mutable state.
///   3. Override [build] to declare the component tree.
///   4. Optionally override [onKey] to handle keyboard events when the
///      screen is focused.
///   5. Call [setState] whenever the state mutates to schedule a re-render.
///
/// ```dart
/// class CounterScreen extends StatefulScreen {
///   const CounterScreen();
///   @override
///   TuiScreenState createState() => _CounterState();
/// }
///
/// class _CounterState extends TuiScreenState {
///   int _count = 0;
///
///   @override
///   Component build(BuildContext context) =>
///     Text('count: $_count');
///
///   @override
///   void onKey(KeyboardEvent event) {
///     if (event.logicalKey == LogicalKey.character('j')) {
///       _count++;
///       setState(() {});
///     }
///   }
/// }
/// ```
library;

import 'package:nocterm/nocterm.dart' as nocterm;

/// The immutable configuration for a stateful Zuraffa TUI screen.
abstract class StatefulScreen extends nocterm.StatefulComponent {
  const StatefulScreen({super.key});

  @override
  TuiScreenState createState();
}

/// The mutable state for a [StatefulScreen].
///
/// Subclasses override [build] to declare the component tree and call
/// [setState] whenever the state mutates. The framework schedules a re-render
/// of the affected view (FR-003).
abstract class TuiScreenState<T extends StatefulScreen> extends nocterm.State<T> {
  /// Called when a keyboard event is delivered to this screen while focused.
  ///
  /// Default implementation does nothing. Override to handle navigation,
  /// form input, etc. Return `true` from a wrapping `Focusable` to absorb
  /// the event; here the screen just observes.
  void onKey(nocterm.KeyboardEvent event) {}

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    // Wrap the screen's tree in a Focusable so the screen receives keyboard
    // events routed to it. onKeyEvent returns false so unhandled events
    // bubble up to parent Focusables (Navigator back handling, etc.).
    return nocterm.Focusable(
      focused: true,
      onKeyEvent: (event) {
        onKey(event);
        return false;
      },
      child: buildScreen(context),
    );
  }

  /// Subclasses override this to declare the screen's component tree.
  ///
  /// Wrapping [build] above gives the framework a single hook to inject
  /// focus + key event routing without touching each screen.
  nocterm.Component buildScreen(nocterm.BuildContext context);
}
