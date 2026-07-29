import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_section.dart';

/// The x-ray debug panel: dark, DevTools-style, grid-based, sectioned,
/// scrollable, dismissible (close button or Escape).
///
/// Fills its constraints — positioning on screen ([OverlayPosition]) is
/// the host's job. Mount via [XRayHost]; never insert it into the app's
/// own widget tree — the host adds/removes it above the app and leaves
/// zero footprint when [XRayPlugin.enabled] is `false`.
class XRayOverlay extends StatefulWidget {
  final XRayConfig config;

  /// Called when the user dismisses the panel (close button or Escape).
  /// The host is responsible for collapsing it into the launcher.
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
    // Grab focus so Escape works without clicking into the panel first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = XRayPlugin();

    return Focus(
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
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF0F1115),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onClose: widget.onClose),
            const Divider(height: 1, color: Color(0xFF2A2D34)),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: plugin.revision,
                builder: (context, _, __) =>
                    _SectionList(config: widget.config, plugin: plugin),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  final XRayConfig config;
  final XRayPlugin plugin;

  const _SectionList({required this.config, required this.plugin});

  @override
  Widget build(BuildContext context) {
    final endpoints = plugin.registeredEndpoints;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config.useCases)
            XRaySection.endpoints(
              sectionId: 'usecases',
              title: 'UseCases',
              entries: endpoints,
              keyBuilder: (e) => XRayElementKey.useCase(e.domain, e.usecase),
              labelBuilder: (e) => '${e.domain}.${e.usecase}',
            ),
          if (config.repositories)
            XRaySection.elements(
              sectionId: 'repositories',
              title: 'Repositories',
              elements: plugin.elementsOf(XRayElementType.repository),
              elementKeyBuilder: (e) =>
                  XRayElementKey.repository(e.domain ?? 'app', e.name),
            ),
          if (config.dataSources)
            XRaySection.elements(
              sectionId: 'datasources',
              title: 'DataSources',
              elements: plugin.elementsOf(XRayElementType.dataSource),
              elementKeyBuilder: (e) =>
                  XRayElementKey.dataSource(e.domain ?? 'app', e.name),
            ),
          if (config.controllers)
            XRaySection.elements(
              sectionId: 'controllers',
              title: 'Controllers',
              elements: plugin.elementsOf(XRayElementType.controller),
              elementKeyBuilder: (e) => XRayElementKey.controller(e.name),
            ),
          if (config.presenters)
            XRaySection.elements(
              sectionId: 'presenters',
              title: 'Presenters',
              elements: plugin.elementsOf(XRayElementType.presenter),
              elementKeyBuilder: (e) =>
                  XRayElementKey.presenter(e.domain ?? 'app', e.name),
            ),
          if (config.services)
            XRaySection.elements(
              sectionId: 'services',
              title: 'Services',
              elements: plugin.elementsOf(XRayElementType.service),
              elementKeyBuilder: (e) => XRayElementKey.service(e.name),
            ),
          if (config.routes)
            XRaySection.elements(
              sectionId: 'routes',
              title: 'Routes',
              elements: plugin.elementsOf(XRayElementType.route),
              elementKeyBuilder: (e) => XRayElementKey.route(e.name),
            ),
          if (config.endpointCatalog)
            XRaySection.endpoints(
              sectionId: 'catalog',
              title: 'Catalog',
              entries: endpoints,
              keyBuilder: (e) => XRayElementKey.endpoint(e.method),
              labelBuilder: (e) =>
                  '${e.method}${e.isStream ? '  ⟲' : ''} → ${e.returns}',
              initiallyExpanded: false,
            ),
          if (endpoints.isEmpty &&
              XRayElementType.values.every((t) => plugin.elementsOf(t).isEmpty))
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No endpoints or elements registered yet.\n'
                'Call ZuraffaApiBridge.init(), your register*ApiBridge() '
                'functions and XRayPlugin().registerElement(...) before '
                'Zuraffa.enableXRay().',
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ],
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
