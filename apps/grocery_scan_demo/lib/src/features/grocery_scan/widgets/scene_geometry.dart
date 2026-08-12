import 'dart:ui';

/// Single source of truth for where elements sit inside the mock camera
/// frame. The scene widgets AND the detection HUD both derive their geometry
/// from here, so highlight boxes always land exactly on the rendered tag or
/// object.
abstract final class SceneGeometry {
  SceneGeometry._();

  /// Shelf price tag (text mode) — the "Heirloom Tomatoes" store tag.
  static Rect tagRect(Size size) => Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.24,
        size.width * 0.72,
        size.height * 0.30,
      );

  /// Object hotspot (produce / meat modes).
  static Rect objectRect(Size size) => Rect.fromLTWH(
        size.width * 0.30,
        size.height * 0.26,
        size.width * 0.40,
        size.height * 0.38,
      );

  /// Mock barcode block (barcode mode).
  static Rect barcodeRect(Size size) => Rect.fromLTWH(
        size.width * 0.32,
        size.height * 0.40,
        size.width * 0.36,
        size.height * 0.20,
      );

  /// Ingredient panel (stethoscope mode) — a package back with the
  /// ingredient list, the thing the customer captures.
  static Rect ingredientsRect(Size size) => Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.24,
        size.width * 0.56,
        size.height * 0.40,
      );

  /// Scan line y position (0..1 of height) for a scan progress in 0..1.
  static double scanLineY(Size size, double progress) =>
      size.height * (0.14 + progress * 0.72);

  /// Vertical mode dock position (right edge, center).
  static Offset dockCenter(Size size) => Offset(
        size.width - 58,
        size.height * 0.52,
      );
}
