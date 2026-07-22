import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_overlay.dart';

/// Wraps the app's root widget so [XRayOverlay] can be inserted as an
/// [OverlayEntry] sitting above everything else — without changing the
/// widget tree at all when x-ray is disabled.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   ZuraffaApiBridge.init();
///   registerProductApiBridge();
///   Zuraffa.enableXRay(XRayConfig(useCases: true));
///
///   runApp(XRayHost(child: MyApp()));
/// }
/// ```
///
/// When [XRayPlugin.enabled] is `false` (release builds, or x-ray never
/// enabled), [build] returns `widget.child` directly — no [Overlay], no
/// extra widget, no extra `Key`s in the tree. This satisfies the
/// "must not interfere with the app's widget tree when disabled" contract.
///
/// When enabled, this host provides its own [Overlay] with explicit
/// [Directionality] so the x-ray debug panel can render above the app
/// without depending on the child tree's Navigator overlay (which isn't
/// available from a root-level wrapper).
class XRayHost extends StatefulWidget {
  final Widget child;
  const XRayHost({required this.child, super.key});

  @override
  State<XRayHost> createState() => _XRayHostState();
}

class _XRayHostState extends State<XRayHost> {
  bool _panelOpen = true;

  void _dismissPanel() => setState(() => _panelOpen = false);

  void _reopenPanel() => setState(() => _panelOpen = true);

  @override
  Widget build(BuildContext context) {
    if (!XRayPlugin().enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Overlay(
        // Key changes force the Overlay to rebuild with new initialEntries,
        // since Overlay only reads initialEntries on its initial build.
        key: ValueKey('xray_panel_$_panelOpen'),
        initialEntries: [
          OverlayEntry(builder: (_) => widget.child),
          if (_panelOpen)
            OverlayEntry(
              builder: (_) => _OverlayShell(
                child: XRayOverlay(
                  config: XRayPlugin().config,
                  onClose: _dismissPanel,
                ),
              ),
            ),
          if (!_panelOpen)
            OverlayEntry(builder: (_) => _OverlayShell(child: _Launcher(onTap: _reopenPanel))),
        ],
      ),
    );
  }
}

/// Provides [Material], [MaterialLocalizations], [ScaffoldMessenger], and a
/// [Navigator] to the x-ray overlay widgets, since the overlay is rendered in
/// a standalone [Overlay] outside the app's [MaterialApp] widget tree.
///
/// Without this shell, `showDialog` (used by [XRayButton] for param forms) and
/// `SnackBar` (used to display results) would fail with missing ancestors.
class _OverlayShell extends StatelessWidget {
  final Widget child;
  const _OverlayShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: Localizations(
          locale: const Locale('en', 'US'),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: Navigator(
            onPopPage: (route, result) => route.didPop(result),
            pages: [
              MaterialPage(
                child: ScaffoldMessenger(
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    backgroundColor: Colors.transparent,
                    body: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small floating re-open affordance shown once the overlay has been
/// closed, so x-ray isn't permanently dismissed for the rest of the debug
/// session.
class _Launcher extends StatelessWidget {
  final VoidCallback onTap;
  const _Launcher({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: const Color(0xFF16181D),
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              key: XRayElementKey.section('launcher'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.biotech, color: Colors.white70, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
