import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';
import 'xray_button.dart';

/// One collapsible panel in the [XRayOverlay] grid — e.g. "UseCases",
/// "Repositories", "Catalog". Renders one [XRayButton] per entry, each
/// with a stable [XRayElementKey]-derived key.
class XRaySection extends StatefulWidget {
  /// Stable identifier used both for [XRayElementKey.section] and as the
  /// visible section title (title-cased by the caller if desired).
  final String sectionId;
  final String title;

  /// Endpoints to render as buttons in this section.
  final List<XRayEndpointInfo> entries;

  /// How to build the button's [Key] and label for a given entry —
  /// different sections key the same underlying endpoint data
  /// differently (e.g. `usecase` keys by domain+usecase, `endpoint` keys
  /// by the full method string).
  final Key Function(XRayEndpointInfo entry) keyBuilder;
  final String Function(XRayEndpointInfo entry) labelBuilder;

  final bool initiallyExpanded;

  const XRaySection({
    required this.sectionId,
    required this.title,
    required this.entries,
    required this.keyBuilder,
    required this.labelBuilder,
    this.initiallyExpanded = true,
    super.key,
  });

  @override
  State<XRaySection> createState() => _XRaySectionState();
}

class _XRaySectionState extends State<XRaySection> {
  late bool _expanded = widget.initiallyExpanded;

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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.title} (${widget.entries.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.entries.isEmpty
                  ? const Text(
                      'No elements registered.',
                      style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.entries.map((entry) {
                        return SizedBox(
                          width: 220,
                          child: XRayButton(
                            elementKey: widget.keyBuilder(entry),
                            label: widget.labelBuilder(entry),
                            endpoint: entry,
                          ),
                        );
                      }).toList(),
                    ),
            ),
        ],
      ),
    );
  }
}
