import 'package:flutter/widgets.dart';

/// Neon color palette for X-Ray bounding boxes.
///
/// Each [XRayScope] gets a distinct color based on a hash of its
/// [viewId], ensuring visual differentiation between views.
class XRayColors {
  XRayColors._();

  static const List<Color> palette = [
    Color(0xFF00FFFF), // Cyan
    Color(0xFFFF00FF), // Magenta
    Color(0xFFFFFF00), // Yellow
    Color(0xFF00FF66), // Spring green
    Color(0xFFFF6600), // Orange
    Color(0xFFFF0066), // Hot pink
    Color(0xFF6633FF), // Electric purple
    Color(0xFF3399FF), // Dodger blue
    Color(0xFFFF3399), // Rose
    Color(0xFF33FFCC), // Aquamarine
  ];

  /// Returns a neon color for the given [viewId].
  ///
  /// Uses a deterministic hash so the same view always gets the same color.
  static Color forView(String viewId) {
    var hash = 0;
    for (var i = 0; i < viewId.length; i++) {
      hash = ((hash << 5) - hash) + viewId.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return palette[hash.abs() % palette.length];
  }

  /// Returns a darker variant for the glow/shadow effect.
  static Color glowFor(Color color) {
    return color.withAlpha(180);
  }

  /// Returns a tinted background for the label pill.
  static Color labelBackgroundFor(Color color) {
    return color.withAlpha(200);
  }
}
