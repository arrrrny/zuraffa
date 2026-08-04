/// Flutter UI layer for Zuraffa.
///
/// Re-exports [zuraffa](https://pub.dev/packages/zuraffa) plus all
/// Flutter-specific types (Controller, Presenter, View, Shells, XRay,
/// state widgets, and the [ZuraffaFlutterPlugin]).
///
/// Flutter apps should depend on **this** package instead of `zuraffa`
/// directly — a single import gives you the full framework.
library;

// ── Re-export everything from the pure-Dart core ─────────────────────
export 'package:zuraffa/zuraffa.dart';

// ── Presentation layer (Flutter widgets) ─────────────────────────────

/// Controller for state management.
export 'package:zuraffa_flutter/src/presentation/controller.dart';

/// Presenter for complex orchestration (optional).
export 'package:zuraffa_flutter/src/presentation/presenter.dart';

/// CleanView and CleanViewState base classes.
export 'package:zuraffa_flutter/src/presentation/view.dart';

/// ResponsiveViewState for responsive layouts.
export 'package:zuraffa_flutter/src/presentation/responsive_view.dart';

/// AdaptiveViewState for platform/device-aware layouts.
export 'package:zuraffa_flutter/src/presentation/adaptive_view.dart';

/// ControlledWidgetBuilder and variants.
export 'package:zuraffa_flutter/src/presentation/controlled_widget.dart';

// ── XRay debugging overlay ────────────────────────────────────────────

export 'package:zuraffa_flutter/src/presentation/xray/xray.dart';

// ── Platform-aware presentation ───────────────────────────────────────

export 'package:zuraffa_flutter/src/presentation/platform/device_class.dart';
export 'package:zuraffa_flutter/src/presentation/platform/platform_class.dart';
export 'package:zuraffa_flutter/src/presentation/platform/platform_context.dart';
export 'package:zuraffa_flutter/src/presentation/platform/platform_layout_resolver.dart';

// ── Application shells ────────────────────────────────────────────────

export 'package:zuraffa_flutter/src/presentation/shells/app_shell.dart';
export 'package:zuraffa_flutter/src/presentation/shells/app_shell_resolver.dart';
export 'package:zuraffa_flutter/src/presentation/shells/mobile_app_shell.dart';
export 'package:zuraffa_flutter/src/presentation/shells/tablet_app_shell.dart';
export 'package:zuraffa_flutter/src/presentation/shells/desktop_app_shell.dart';
export 'package:zuraffa_flutter/src/presentation/shells/macos_app_shell.dart';

// ── State widgets ─────────────────────────────────────────────────────

/// ControlledWidget — base widget with typed controller and lifecycle hooks.
export 'package:zuraffa_flutter/src/state/widgets/controlled_widget.dart';

/// SignalBuilder — rebuilds on pure UI Signal changes.
export 'package:zuraffa_flutter/src/state/widgets/signal_builder.dart';

/// FragmentBuilder — widget subscribing to a single slice.
export 'package:zuraffa_flutter/src/state/widgets/fragment_builder.dart';

// ── Module UI adapters ────────────────────────────────────────────────

/// Route builder typedef (Widget Function(BuildContext, Object?)).
export 'package:zuraffa_flutter/src/module/route_builder.dart';

/// Minimal widget that resolves routes from a ZuraffaEngine.
export 'package:zuraffa_flutter/src/module/app_runner.dart';

// ── Flutter Plugin ────────────────────────────────────────────────────

/// ZuraffaFlutterPlugin wires UI services into the ZuraffaEngine.
export 'package:zuraffa_flutter/src/zuraffa_flutter_plugin.dart';

// ── Controller access ─────────────────────────────────────────────────

/// ZuraffaControllerAccess.getController — retrieves a [Controller] from the widget tree.
export 'package:zuraffa_flutter/src/controller_access.dart';
