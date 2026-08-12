import '../models/store_offer.dart';

/// Mock catalog of stores the comparison engine "searches" in-store.
///
/// In the real product this would come from the price-matching backend; here
/// it is a fixed set so the UI/UX can be iterated on without wiring.
abstract final class StoresCatalog {
  StoresCatalog._();

  /// Nearby stores. [isBestPrice] is computed by the provider at compare time,
  /// so offers here are unmarked.
  static const List<StoreOffer> nearby = [
    StoreOffer(
      brand: StoreBrand.albertsons,
      price: 5.99,
      distanceMiles: 2.1,
    ),
    StoreOffer(
      brand: StoreBrand.walmart,
      price: 6.99,
      distanceMiles: 1.4,
    ),
    StoreOffer(
      brand: StoreBrand.safeway,
      price: 7.49,
      distanceMiles: 3.8,
    ),
    StoreOffer(
      brand: StoreBrand.wholeFoods,
      price: 8.99,
      distanceMiles: 4.2,
    ),
  ];

  /// Small deterministic price jitter per item so two products never render
  /// identical offers (keeps the mock believable).
  static List<StoreOffer> offersForItem(String itemId) {
    final seed = itemId.codeUnits.fold<int>(0, (a, b) => a + b);
    return [
      for (final (i, offer) in nearby.indexed)
        StoreOffer(
          brand: offer.brand,
          price: offer.price + ((seed + i) % 3) * 0.2,
          distanceMiles: offer.distanceMiles,
          inStore: offer.inStore,
        ),
    ];
  }
}
