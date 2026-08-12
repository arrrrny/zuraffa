import 'package:flutter/material.dart';

/// Known store brands rendered by [BrandLogo].
enum StoreBrand {
  walmart,
  albertsons,
  safeway,
  wholeFoods;

  String get displayName => switch (this) {
        StoreBrand.walmart => 'Walmart',
        StoreBrand.albertsons => 'Albertsons',
        StoreBrand.safeway => 'Safeway',
        StoreBrand.wholeFoods => 'Whole Foods',
      };

  /// Brand color used for the logo mark.
  Color get color => switch (this) {
        StoreBrand.walmart => const Color(0xFF0071CE),
        StoreBrand.albertsons => const Color(0xFFC8102E),
        StoreBrand.safeway => const Color(0xFF037D50),
        StoreBrand.wholeFoods => const Color(0xFF274E13),
      };
}

/// A single price offer found by the (mock) comparison engine.
class StoreOffer {
  const StoreOffer({
    required this.brand,
    required this.price,
    this.unit = 'lb',
    this.distanceMiles,
    this.isBestPrice = false,
    this.inStore = true,
  });

  final StoreBrand brand;

  /// Price per [unit], e.g. 6.99 → "$6.99 / lb".
  final double price;

  final String unit;

  /// Distance from the user's location, shown as "1.4 mi".
  final double? distanceMiles;

  /// True for the cheapest offer (renders the "Best price" badge).
  final bool isBestPrice;

  /// False → online order instead of in-store pick-up (renders "Ship").
  final bool inStore;

  String get priceLabel => '\$${price.toStringAsFixed(2)}';

  String get distanceLabel =>
      distanceMiles == null ? '' : '${distanceMiles!.toStringAsFixed(1)} mi';

  String get perUnitLabel => '/ $unit';
}
