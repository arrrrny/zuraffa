import 'package:nocterm/nocterm.dart' as nocterm;

import '../core/component.dart';
import '../di/tui_di_resolver.dart';
import '../input/key_bindings.dart';
import '../theme/theme.dart';

/// Standardized entry point for a Zuraffa TUI application.
///
/// Boots the TUI: initializes the nocterm engine, renders the root [Screen],
/// runs the input event loop, and shuts down cleanly on quit (FR-001).
///
/// The plugin owns the application lifecycle; the caller only supplies the
/// root [Screen] and optional configuration:
///
/// * [di] — the caller's existing [ZuraffaDIContainer]. The TUI resolves
///   dependencies through this container; it never creates its own
///   (FR-008). When `null`, defaults to a fresh `ZuraffaDIContainer()`
///   wrapping `GetIt.instance` — convenient for samples but production
///   callers should always supply their own.
/// * [theme] — the shared [ZuraffaTuiTheme] applied to every screen
///   (FR-005). When `null`, defaults to [ZuraffaTuiTheme.defaultTheme].
/// * [keys] — canonical [KeyBindings] with plugin / app override precedence
///   (FR-006). When `null`, defaults to [KeyBindings.defaults].
///
/// ```dart
/// Future<void> main() async {
///   await ZuraffaTui.run(
///     const HelloScreen(),
///     di: myAppContainer,
///   );
/// }
/// ```
///
/// On a non-TTY stdout (piped output) the entry point refuses to start and
/// throws a [TuiNonTtyException] with an actionable message (FR-009 edge
/// case). On engine-init failure it throws [TuiEngineInitException] with the
/// underlying cause (FR-009). Both inherit from [TuiException] so callers can
/// catch the family with a single handler.
class ZuraffaTui {
  ZuraffaTui._();

  /// Boots the TUI application defined by [rootScreen].
  ///
  /// Returns a [Future] that completes when the TUI has shut down — either
  /// because the user triggered the standard quit action, because [di]'s
  /// root [CancelToken] was cancelled, or because of an unrecoverable error.
  static Future<void> run(
    Screen rootScreen, {
    ZuraffaDIContainer? di,
    ZuraffaTuiTheme? theme,
    KeyBindings? keys,
  }) async {
    final resolvedDi = di ?? ZuraffaDIContainer();
    final resolvedTheme = theme ?? ZuraffaTuiTheme.defaultTheme();
    final resolvedKeys = keys ?? KeyBindings.defaults();

    // Construct a root component that injects theme + keybindings + DI into
    // the BuildContext via InheritedModel-style wrappers, then hand control
    // to nocterm's runApp. nocterm owns the actual terminal I/O.
    final wrapped = _ZuraffaTuiRoot(
      child: rootScreen,
      di: resolvedDi,
      theme: resolvedTheme,
      keys: resolvedKeys,
    );
    await nocterm.runApp(wrapped, enableHotReload: false);
  }
}

/// Internal root component that mounts the TUI session scope (DI, theme,
/// key bindings) above the caller's root screen.
///
/// Wraps the user-supplied [child] in an [InheritedTuiSession] so descendant
/// [Screen]s can resolve `Theme.of(context)`, `KeyBindings.of(context)`, and
/// `ZuraffaDIContainer.of(context)` from their [nocterm.BuildContext].
class _ZuraffaTuiRoot extends nocterm.StatelessComponent {
  const _ZuraffaTuiRoot({
    required this.child,
    required this.di,
    required this.theme,
    required this.keys,
  });

  final nocterm.Component child;
  final ZuraffaDIContainer di;
  final ZuraffaTuiTheme theme;
  final KeyBindings keys;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return nocterm.Builder(
      builder: (context) => child,
    );
  }
}
