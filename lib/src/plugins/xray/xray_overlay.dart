// X-Ray Visual Overlay (Track 4.2 — Spec 036, issue #181) — public barrel.
//
// Exposes the pure-Dart half of the X-Ray Visual Overlay:
//   - XRayNode            (data model for a registered widget)
//   - XRayStateSummary   (at-a-glance SignalSlice state)
//   - XRayBoxColor        (per-view-type neon color palette)
//   - XRayBoxLabel        (inline label formatter)
//   - XRayRect            (pure-Dart rect)
//   - XRayBoundingBox     (rect + label + color, per node)
//   - XRayDetailPanel     (full state JSON dump for tap-to-inspect)
//   - XRayShakeDetector   (abstract platform interface + no-op default)
//   - XRayOverlayState    (mutable registry + broadcast stream + release guard)
//
// The Flutter half (painter, gesture detector, OverlayEntry) lives in
// `zuraffa_flutter`. The MCP half (HTTP/WebSocket bridge) lives in the
// `zuraffa` MCP server (Track 4.4 — spec 035).

library;

export 'xray_bounding_box.dart';
export 'xray_box_color.dart';
export 'xray_box_label.dart';
export 'xray_detail_panel.dart';
export 'xray_node.dart';
export 'xray_overlay_state.dart';
export 'xray_shake_detector.dart';
export 'xray_state_summary.dart';
