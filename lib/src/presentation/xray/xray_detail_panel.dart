import 'dart:convert';

import 'package:flutter/material.dart';

import 'xray_node_metadata.dart';

/// A panel that shows detailed information about a selected X-Ray node.
///
/// Displays:
/// - Full node ID
/// - Enabled / disabled state
/// - Bound action name
/// - Full state JSON (from [XRayMetadataRegistry])
///
/// The panel can be dismissed by tapping the close button or the backdrop.
class XRayDetailPanel extends StatelessWidget {
  /// The full deterministic node ID (e.g. 'ProfileView.saveButton').
  final String nodeId;

  /// Optional metadata attached to this node.
  final XRayNodeMetadata? metadata;

  /// The neon color associated with the parent view.
  final Color viewColor;

  /// Callback when the user dismisses the panel.
  final VoidCallback onClose;

  const XRayDetailPanel({
    super.key,
    required this.nodeId,
    this.metadata,
    required this.viewColor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xDD1A1A2E);
    const textColor = Color(0xFFE0E0E0);
    const dimTextColor = Color(0xFF888888);

    final stateJson = metadata?.stateJson;
    final stateString = stateJson != null
        ? const JsonEncoder.withIndent('  ').convert(stateJson)
        : null;

    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: const Color(0x88000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // Consume tap on the panel itself.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: viewColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: viewColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Node Inspector',
                              style: TextStyle(
                                color: viewColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF333355),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'X',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Node ID.
                      _buildRow('Node ID', nodeId, textColor, dimTextColor),
                      const SizedBox(height: 8),

                      // Enabled state.
                      _buildRow(
                        'State',
                        metadata?.isEnabled == false ? 'DISABLED' : 'ENABLED',
                        metadata?.isEnabled == false
                            ? const Color(0xFFFF4444)
                            : const Color(0xFF44FF44),
                        dimTextColor,
                      ),
                      const SizedBox(height: 8),

                      // Action name.
                      _buildRow(
                        'Action',
                        metadata?.actionName ?? '—',
                        textColor,
                        dimTextColor,
                      ),

                      // State JSON.
                      if (stateString != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'State JSON',
                          style: TextStyle(
                            color: dimTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D1A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            stateString,
                            style: const TextStyle(
                              color: Color(0xFFAADDFF),
                              fontSize: 11,
                              fontFamily: 'monospace',
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontFamily: 'monospace',
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}
