// X-Ray box label — formats the inline label string that is rendered on
// top of each bounding box.
//
// Format (canonical):
//   "<nodeId> | <status> | →<boundAction> | <stateWord> [<preview>]"
//
// Where:
//   - status  is "enabled" or "disabled"
//   - →action is omitted when boundAction is null
//   - stateWord is one of { data, error, loading, idle }
//   - preview is appended only when dataPreview or errorPreview is set
//
// Pure-Dart, no Flutter dependency. Immutable.
//
// Track 4.2 — Spec 036 (issue #181, FR-003, FR-008).
library;

import 'xray_state_summary.dart';

/// Inline label data for a single X-Ray bounding box.
///
/// The Flutter painter calls [format] to get the rendered string. Tests
/// assert the canonical format so the MCP bridge / detail panel can
/// round-trip the same string.
class XRayBoxLabel {
  /// The node's deterministic id (e.g. `"ProfileViewNode.editProfileButton"`).
  final String nodeId;

  /// `"enabled"` or `"disabled"`.
  final String status;

  /// Optional bound action name (e.g. `"onEditTapped"`).
  final String? boundAction;

  /// At-a-glance state summary.
  final XRayStateSummary stateSummary;

  const XRayBoxLabel({
    required this.nodeId,
    required this.status,
    required this.stateSummary,
    this.boundAction,
  });

  /// Format the inline label string.
  ///
  /// Format: `"<nodeId> | <status> [| →<boundAction>] | <stateWord> [| <preview>]"`
  String format() {
    final parts = <String>[nodeId, status];
    if (boundAction != null && boundAction!.isNotEmpty) {
      parts.add('→$boundAction');
    }
    parts.add(stateSummary.statusWord);
    final preview = stateSummary.hasData
        ? stateSummary.dataPreview
        : (stateSummary.hasError ? stateSummary.errorPreview : null);
    if (preview != null && preview.isNotEmpty) {
      parts.add(preview);
    }
    return parts.join(' | ');
  }

  @override
  String toString() => format();
}
