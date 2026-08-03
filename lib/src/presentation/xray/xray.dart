/// X-Ray deterministic widget identity infrastructure.
///
/// Provides compiler-verified node identifiers for interactive elements
/// in generated views. Foundation for visual X-Ray overlay (Track 4.2),
/// Control Deck synthetic payload injection (Track 4.3), and
/// AI agent bridge (Track 4.4).
///
/// NOTE: [xray_bridge_server.dart] is not exported from this barrel because
/// it depends on dart:io and is not compatible with Flutter web. Import it
/// directly when needed: `import 'package:zuraffa/src/presentation/xray/xray_bridge_server.dart';`
library;

export 'xray_mode.dart';
export 'xray_node.dart';
export 'xray_scope.dart';
export 'xray_node_metadata.dart';
export 'xray_colors.dart';
export 'xray_detail_panel.dart';
export 'xray_shake_detector.dart';
export 'xray_activation.dart';
export 'xray_scope_overlay.dart';
export 'xray_mock_annotation.dart';
export 'xray_mock_entry.dart';
export 'xray_mock_parser.dart';
export 'xray_control_deck.dart';
export 'xray_bridge.dart';
// NOTE: xray_bridge_server.dart is NOT exported (dart:io dependency, web-incompatible)
// Import directly if needed on native platforms:
// import 'package:zuraffa/src/presentation/xray/xray_bridge_server.dart';
