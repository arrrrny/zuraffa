import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_overlay.dart';

/// Mounts the x-ray debug overlay above the app without disturbing it.
///
/// ```dart
/// void main() {
///   ZuraffaApiBridge.init();
///   registerProductApiBridge();
///   Zuraffa.enableXRay(const XRayConfig(useCases: true));
///   runApp(const XRayHost(child: MyApp()));
/// }
/// ```
///
/// Design notes:
///
/// - **Zero footprint when disabled**: [XRayPlugin.enabled] is `false`
///   (release builds, or x-ray never enabled) -> [build] returns
///   [child] directly. No extra widgets, no keys, no overhead.
/// - **No app-state loss on dismiss/reopen**: [child] stays at a stable
///   [Stack] position while only the overlay layer toggles between panel
///   and launcher. (Swapping an `Overlay`'s key or entry list would
///   remount the whole app subtree — avoided here on purpose.)
/// - **Touches pass through**: the overlay layer occupies only the
///   panel's rectangle (or the launcher's), positioned via [Positioned]
///   with explicit bounds. Everywhere else, gestures fall through to the
///   app — the panel never swallows them.
class XRayHost extends StatefulWidget {
  final Widget child;
  const XRayHost({required this.child, super.key});

  @override
  State<XRayHost> createState() => _XRayHostState();
}

class _XRayHostState extends State<XRayHost> {
  static const double _sizeFactor = 0.86;
  static const double _margin = 16;

  bool _panelOpen = true;

  void _dismiss() => setState(() => _panelOpen = false);
  void _reopen() => setState(() => _panelOpen = true);

  /// Screen size without requiring a [MediaQuery] ancestor — [XRayHost]
  /// is typically placed *above* `MaterialApp`, where none exists.
  Size _screenSize(BuildContext context) {
    final query = MediaQuery.maybeOf(context);
    if (query != null) return query.size;
    final view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }

  Positioned _panelPosition(Size screen, OverlayPosition position) {
    final width = screen.width * _sizeFactor;
    final height = screen.height * _sizeFactor;
    final child = _PanelShell(
      child: XRayOverlay(config: XRayPlugin().config, onClose: _dismiss),
    );
    switch (position) {
      case OverlayPosition.topLeft:
        return Positioned(
          left: _margin,
          top: _margin,
          width: width,
          height: height,
          child: child,
        );
      case OverlayPosition.topRight:
        return Positioned(
          right: _margin,
          top: _margin,
          width: width,
          height: height,
          child: child,
        );
      case OverlayPosition.bottomLeft:
        return Positioned(
          left: _margin,
          bottom: _margin,
          width: width,
          height: height,
          child: child,
        );
      case OverlayPosition.bottomRight:
        return Positioned(
          right: _margin,
          bottom: _margin,
          width: width,
          height: height,
          child: child,
        );
    }
  }

  Positioned _launcherPosition(OverlayPosition position) {
    final child = Directionality(
      textDirection: TextDirection.ltr,
      child: SafeArea(child: _Launcher(onTap: _reopen)),
    );
    switch (position) {
      case OverlayPosition.topLeft:
        return Positioned(left: _margin, top: _margin, child: child);
      case OverlayPosition.topRight:
        return Positioned(right: _margin, top: _margin, child: child);
      case OverlayPosition.bottomLeft:
        return Positioned(left: _margin, bottom: _margin, child: child);
      case OverlayPosition.bottomRight:
        return Positioned(right: _margin, bottom: _margin, child: child);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugin = XRayPlugin();
    if (!plugin.enabled) return widget.child;

    final position = plugin.config.overlayPosition;
    final screen = _screenSize(context);
    return Stack(
      // XRayHost usually sits *above* MaterialApp, where no ambient
      // Directionality exists yet.
      textDirection: TextDirection.ltr,
      children: [
        // Index 0: the app itself. Never remounted by x-ray toggles.
        widget.child,
        // Index 1: only the panel (or launcher) rectangle — gestures
        // outside it fall through to the app.
        if (_panelOpen)
          _panelPosition(screen, position)
        else
          _launcherPosition(position),
      ],
    );
  }
}

/// Floating re-open affordance shown while the panel is dismissed.
class _Launcher extends StatelessWidget {
  final VoidCallback onTap;
  const _Launcher({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16181D),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        key: XRayElementKey.overlayLauncher,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.biotech, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

/// Gives the panel the [Material], [MaterialLocalizations],
/// [ScaffoldMessenger] and [Navigator] ancestors it needs, since it lives
/// outside the app's [MaterialApp] subtree.
///
/// The shell wraps only the panel itself (not the whole screen), so it
/// never intercepts gestures meant for the app underneath.
class _PanelShell extends StatelessWidget {
  final Widget child;
  const _PanelShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
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
    );
  }
}
