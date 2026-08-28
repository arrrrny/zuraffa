/// Edge-case handling for the TUI plugin (FR-009).
///
/// Each subclass of [TuiException] represents an edge case the plugin MUST
/// surface as a clear, actionable error rather than a raw crash or hang:
///
/// * [TuiNonTtyException] — non-interactive terminal (piped stdout).
/// * [TuiEngineInitException] — nocterm cannot initialize the terminal.
/// * [TuiResizeException] — resize event could not be applied (rare; usually
///   silently reflows).
///
/// All inherit from [TuiException] so callers can catch the family with a
/// single handler.
library;

import 'dart:io';

/// Base class for all TUI plugin exceptions.
class TuiException implements Exception {
  const TuiException(this.message, {this.cause});

  /// Human-readable, actionable message describing the failure.
  final String message;

  /// The underlying cause, if any.
  final Object? cause;

  @override
  String toString() {
    final causeStr = cause == null ? '' : ' (cause: $cause)';
    return 'TuiException: $message$causeStr';
  }
}

/// Thrown when the TUI is asked to start on a non-interactive terminal.
///
/// FR-009 edge case "Non-interactive output (no TTY / piped stdout)": the
/// plugin MUST detect a non-interactive terminal and either refuse to start
/// with a clear message OR fall back to a non-interactive mode, rather than
/// hanging or corrupting output.
class TuiNonTtyException extends TuiException {
  const TuiNonTtyException(String message, {super.cause}) : super(message);
}

/// Thrown when the TUI engine (nocterm) cannot initialize the terminal.
///
/// FR-009 edge case "Rendering engine unavailable (native deps missing)": if
/// the underlying TUI engine cannot initialize the terminal (missing native
/// libraries, unsupported platform), the plugin MUST fail with an actionable
/// message, not a raw crash.
class TuiEngineInitException extends TuiException {
  const TuiEngineInitException(String message, {super.cause}) : super(message);
}

/// TTY guard — detects whether stdout is attached to a real terminal.
///
/// FR-009 edge case "Non-interactive output (no TTY / piped stdout)".
class TtyGuard {
  const TtyGuard();

  /// Returns `true` if [stdout] is attached to a real TTY.
  ///
  /// Uses [stdout.supportsAnsiEscapes] plus an explicit `term` check so that
  /// piped output (e.g. `zuraffa_tui_app | tee log.txt`) is detected even on
  /// platforms where the former lies.
  bool isTty() {
    if (stdout.supportsAnsiEscapes == false) return false;
    if (stdout.hasTerminal == false) return false;
    return true;
  }

  /// Throws [TuiNonTtyException] with an actionable message unless [isTty]
  /// returns `true`. Apps that prefer a non-interactive fallback should call
  /// [isTty] directly and branch.
  void requireTty() {
    if (!isTty()) {
      throw const TuiNonTtyException(
        'Zuraffa TUI requires an interactive terminal (TTY). '
        'Detected non-TTY stdout (piped or redirected). '
        'Run from a real terminal, or redirect stderr only.',
      );
    }
  }
}

/// Resize handler — relays new terminal dimensions to listeners so the layout
/// can reflow (FR-009 edge case "Terminal too small / resize").
///
/// The actual SIGWINCH subscription is owned by nocterm's StdioBackend; this
/// handler is the abstraction Zuraffa TUI screens use to register listeners
/// without depending on nocterm internals.
class ResizeHandler {
  ResizeHandler();

  final List<void Function(int cols, int rows)> _listeners = [];

  /// Registers a listener that is invoked whenever the terminal resizes.
  void addListener(void Function(int cols, int rows) listener) {
    _listeners.add(listener);
  }

  /// Removes a previously-registered listener.
  void removeListener(void Function(int cols, int rows) listener) {
    _listeners.remove(listener);
  }

  /// Relays a new terminal size to all registered listeners.
  ///
  /// Called by the runtime when nocterm emits a resize signal. Listeners
  /// typically call `setState(() {})` on their owning screen to trigger a
  /// reflow.
  void relayResize(int cols, int rows) {
    for (final listener in List.of(_listeners)) {
      listener(cols, rows);
    }
  }

  /// Whether any listeners are registered.
  bool get hasListeners => _listeners.isNotEmpty;
}
