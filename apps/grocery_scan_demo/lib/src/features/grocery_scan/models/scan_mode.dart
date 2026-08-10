import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../models/grocery_item.dart';

/// The five capture modes of the price-match camera.
///
/// - [barcode]: default camera home — points at a barcode (mocked here).
/// - [text]: ML Kit *text* detection — reads in-store price tags / product
///   tags and uses the largest single text as the item name.
/// - [produce]: object detection for fruit/vegetables — requires an approval
///   of the exact item when the embedded dictionary has variants.
/// - [meat]: object detection for meat cuts — same approval flow. Kept as a
///   separate button because produce and meat can run different detection
///   models (and the UI affordance is clearer split).
/// - [ingredients]: capture a photo of the ingredient list and check it —
///   gluten verdict + health nutrition score (AI-backed when wired).
enum ScanMode {
  barcode,
  text,
  produce,
  meat,
  ingredients;

  String get label => switch (this) {
        ScanMode.barcode => 'Barcode',
        ScanMode.text => 'Text detection',
        ScanMode.produce => 'Object · Produce',
        ScanMode.meat => 'Object · Meat',
        ScanMode.ingredients => 'Ingredient check',
      };

  String get hint => switch (this) {
        ScanMode.barcode => 'Point at a barcode',
        ScanMode.text => 'Point at a price tag — auto-detect',
        ScanMode.produce => 'Hold the item in frame to scan',
        ScanMode.meat => 'Hold the cut in frame to scan',
        ScanMode.ingredients => 'Point at the ingredient list — capture',
      };

  /// Overlay-button icon (fruit / meat / text / barcode / stethoscope).
  IconData get icon => switch (this) {
        ScanMode.barcode => LucideIcons.qrCode,
        ScanMode.text => LucideIcons.textCursorInput,
        ScanMode.produce => LucideIcons.apple,
        ScanMode.meat => LucideIcons.beef,
        ScanMode.ingredients => LucideIcons.stethoscope,
      };

  bool get isObjectMode => this == ScanMode.produce || this == ScanMode.meat;

  /// Detection model / demo category for object modes. Produce and meat can
  /// run separate models, so the mode carries its own category.
  GroceryCategory? get objectCategory => switch (this) {
        ScanMode.produce => GroceryCategory.produce,
        ScanMode.meat => GroceryCategory.meat,
        _ => null,
      };
}
