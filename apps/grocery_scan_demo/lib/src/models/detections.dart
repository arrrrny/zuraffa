import 'grocery_item.dart';

/// One text block detected by the (mock) ML Kit text scanner.
class TextBlock {
  const TextBlock({required this.text, required this.confidence});

  final String text;

  /// 0..1 — how sure the scanner is about this block.
  final double confidence;
}

/// Result of a mock text-detection pass over the camera frame.
///
/// [primary] is the largest single text block — the heuristic used to pick
/// the product name (e.g. "HEIRLOOM TOMATOES" off a store shelf tag).
class TextDetectionResult {
  const TextDetectionResult({required this.blocks, required this.primary});

  final List<TextBlock> blocks;
  final TextBlock primary;
}

/// Result of a mock object-detection pass (produce / meat).
class ObjectDetectionResult {
  const ObjectDetectionResult({required this.item, required this.confidence});

  final GroceryItem item;

  /// 0..1 confidence of the detector.
  final double confidence;
}
