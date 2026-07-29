import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_button.dart';

/// One collapsible panel of the [XRayOverlay] grid (e.g. "UseCases",
/// "Repositories", "Catalog"). Renders its entries as a wrapping grid of
/// buttons, each with a stable [XRayElementKey]-derived key.
///
/// Use [XRaySection.endpoints] for sections backed by the api bridge's
/// endpoint catalog and [XRaySection.elements] for sections backed by
/// [XRayPlugin]'s element registry.
class XRaySection extends StatefulWidget {
  /// Stable id for [XRayElementKey.section]; also drives the visible title.
  final String sectionId;
  final String title;

  /// Endpoint-backed entries (null when this is an element section).
  final List<XRayEndpointInfo>? entries;

  /// Registry-backed entries (null when this is an endpoint section).
  final List<XRayElement>? elements;

  final Key Function(XRayEndpointInfo entry)? keyBuilder;
  final String Function(XRayEndpointInfo entry)? labelBuilder;
  final Key Function(XRayElement element)? elementKeyBuilder;

  final bool initiallyExpanded;

  const XRaySection.endpoints({
    required this.sectionId,
    required this.title,
    required List<XRayEndpointInfo> this.entries,
    required Key Function(XRayEndpointInfo entry) this.keyBuilder,
    required String Function(XRayEndpointInfo entry) this.labelBuilder,
    this.initiallyExpanded = true,
    super.key,
  }) : elements = null,
       elementKeyBuilder = null;

  const XRaySection.elements({
    required this.sectionId,
    required this.title,
    required List<XRayElement> this.elements,
    required Key Function(XRayElement element) this.elementKeyBuilder,
    this.initiallyExpanded = true,
    super.key,
  }) : entries = null,
       keyBuilder = null,
       labelBuilder = null;

  @override
  State<XRaySection> createState() => _XRaySectionState();
}

class _XRaySectionState extends State<XRaySection> {
  late bool _expanded = widget.initiallyExpanded;

  int get _count => widget.entries?.length ?? widget.elements?.length ?? 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: XRayElementKey.section(widget.sectionId),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2D34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D34),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_count',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFF2A2D34)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _count == 0
                  ? const Text(
                      'No elements registered.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.entries != null)
                          for (final e in widget.entries!)
                            XRayButton.endpoint(
                              elementKey: widget.keyBuilder!(e),
                              label: widget.labelBuilder!(e),
                              endpoint: e,
                            ),
                        if (widget.elements != null)
                          for (final e in widget.elements!)
                            XRayButton.element(
                              elementKey: widget.elementKeyBuilder!(e),
                              element: e,
                            ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
