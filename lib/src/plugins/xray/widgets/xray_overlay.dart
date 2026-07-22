import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_section.dart';

/// Full-screen x-ray debug overlay.
///
/// Insert this via an [OverlayEntry] (see `XRayHost` / the app-level
/// integration snippet in the README) rather than mounting it directly in
/// the widget tree, so it can sit above *everything* the app renders,
/// including dialogs and other overlays, and so it can be dropped entirely
/// with zero footprint when [XRayPlugin.enabled] is `false`.
///
/// Behaves like DevTools-in-the-app: dark theme, collapsible sections, one
/// button per generated element, a fixed-position launcher/close affordance,
/// and an Escape-key shortcut for keyboard dismissal.
class XRayOverlay extends StatefulWidget {
  final XRayConfig config;

  /// Called when the user dismisses the overlay (close button or Escape).
  /// The host is responsible for actually removing the [OverlayEntry].
  final VoidCallback? onClose;

  const XRayOverlay({required this.config, this.onClose, super.key});

  @override
  State<XRayOverlay> createState() => _XRayOverlayState();
}

class _XRayOverlayState extends State<XRayOverlay> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Grab focus so the Escape shortcut works immediately without the user
    // needing to click into the overlay first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Alignment _alignmentFor(OverlayPosition position) {
    switch (position) {
      case OverlayPosition.topLeft:
        return Alignment.topLeft;
      case OverlayPosition.topRight:
        return Alignment.topRight;
      case OverlayPosition.bottomLeft:
        return Alignment.bottomLeft;
      case OverlayPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugin = XRayPlugin();
    final endpoints = plugin.registeredEndpoints;
    final config = widget.config;

    return Align(
      alignment: _alignmentFor(config.overlayPosition),
      child: FractionallySizedBox(
        widthFactor: 0.86,
        heightFactor: 0.86,
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose?.call();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Material(
            key: XRayElementKey.overlayRoot,
            elevation: 12,
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF0F1115),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: widget.onClose),
                const Divider(height: 1, color: Color(0xFF2A2D34)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (config.useCases)
                          XRaySection(
                            sectionId: 'usecases',
                            title: 'UseCases',
                            entries: endpoints,
                            keyBuilder: (e) =>
                                XRayElementKey.useCase(e.domain, e.usecase),
                            labelBuilder: (e) => '${e.domain}.${e.usecase}',
                          ),
                        if (config.repositories)
                          XRaySection(
                            sectionId: 'repositories',
                            title: 'Repositories',
                            entries: const [],
                            keyBuilder: (e) => XRayElementKey.repository(
                              e.domain,
                              e.usecase,
                            ),
                            labelBuilder: (e) => e.usecase,
                          ),
                        if (config.dataSources)
                          XRaySection(
                            sectionId: 'datasources',
                            title: 'DataSources',
                            entries: const [],
                            keyBuilder: (e) => XRayElementKey.dataSource(
                              e.domain,
                              e.usecase,
                            ),
                            labelBuilder: (e) => e.usecase,
                          ),
                        if (config.endpointCatalog)
                          XRaySection(
                            sectionId: 'catalog',
                            title: 'Catalog',
                            entries: endpoints,
                            keyBuilder: (e) =>
                                XRayElementKey.endpoint(e.method),
                            labelBuilder: (e) =>
                                '${e.method}${e.isStream ? '  ⟲' : ''} → ${e.returns}',
                            initiallyExpanded: false,
                          ),
                        if (endpoints.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No endpoints registered yet.\n'
                              'Call ZuraffaApiBridge.init() and your '
                              'register*ApiBridge() functions before '
                              'Zuraffa.enableXRay().',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onClose;
  const _Header({this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.biotech, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          const Text(
            'x-ray',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            key: XRayElementKey.overlayClose,
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            tooltip: 'Close (Esc)',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
