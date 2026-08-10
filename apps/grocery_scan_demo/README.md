# ZikZak Grocery Price Match — Standalone UI/UX Mock

A **self-contained** Flutter mock app demonstrating the in-store grocery
price-comparison camera: barcode scan → ML Kit text detection (price tags) and
object detection (produce/meat) with a localized item dictionary, all rendered
**on the camera page** with overlays and transitions — no bottom sheets, no
leaving the viewfinder.

Built 100% on [shadcn_ui](https://pub.dev/packages/shadcn_ui) (`^0.56.1`) and
its derivatives. Everything is mocked through `MockGroceryProvider`, so an
external cloud agent can iterate on UI/UX without any backend, camera, or ML
wiring.

## Run it

```bash
cd apps/grocery_scan_demo
flutter pub get
flutter run          # iOS simulator / Android / macOS
flutter test         # UI/UX smoke tests (state machine pinned)
```

## Demo script (60 seconds)

1. **Permission** — location prompt (mocked OS dialog). *Allow.*
2. **Barcode mode** (default) — tap the shutter → toast explains it's mocked.
3. **Text detection** — tap the **text icon** in the right dock. The camera
   points at a shelf tag: `Heirloom Tomatoes` is highlighted as the *largest
   single text* (97%), and within ~3 s the price overlay reveals on-camera:
   Albertsons `$5.99/lb` (BEST) · Walmart `$6.99/lb · 1.4 mi` · +2 more stores.
4. **Object detection** — tap the **fruit icon**. The camera frames a tomato.
   *Hold* it (or tap the shutter) → hold ring fills → detection highlights
   `Tomatoes · 94%` → the on-camera chooser appears because the embedded
   dictionary has variants (`Tomatoes` / `Organic Tomatoes` / `Heirloom
   Tomatoes`). While the chooser is up, prices are **pre-fetched in parallel
   for every variant** — each row shows its best in-store price (store logo +
   count-up animation) as it lands. Pick one → instant price reveal.
5. **Edge case** — tap the object to cycle it (tomato → **cantaloupe** →
   avocado). Cantaloupe has **no dictionary variants**, so the chooser is
   skipped and prices appear directly.
6. **Meat** — tap the **meat icon** (separate button/model): ribeye / chicken
   with the same hold-to-scan + approve + pre-fetched-price flow.

Everything happens **on the camera page**. Prices count up, rows stagger in,
store logos are vector-drawn (Walmart spark, Albertsons mark).

## Architecture map (modular by design)

```
lib/
├── main.dart
└── src/
    ├── app.dart                        # root: ShadTheme + ShadToaster + DI scope
    ├── theme/app_theme.dart            # shadcn token set (emerald-on-ink camera)
    ├── models/                         # pure data: GroceryItem, StoreOffer,
    │                                   #   TextDetection/ObjectDetection results
    ├── data/
    │   ├── grocery_dictionary.dart     # EMBEDDED localized item dictionary
    │   │                               #   (en-US, tr-TR) → drives the variant
    │   │                               #   chooser edge case, offline in-store
    │   └── stores_catalog.dart         # nearby stores (Walmart 1.4 mi, …)
    ├── providers/
    │   ├── mock_grocery_provider.dart  # the MockProvider: permission, scanText,
    │   │                               #   scanObject, comparePrices + timings
    │   └── mock_grocery_scope.dart     # DI (swap a real provider here)
    └── features/grocery_scan/
        ├── grocery_scan_page.dart      # scan-session state machine
        ├── models/scan_mode.dart       # barcode | text | produce | meat
        └── widgets/
            ├── camera_viewfinder.dart  # mock scene + gestures (hold/tap)
            ├── scene_painters.dart     # tomato/cantaloupe/avocado/steak/chicken
            ├── scene_geometry.dart     # single source of truth for HUD alignment
            ├── detection_hud.dart      # highlight boxes + confidence chips
            ├── scan_mode_dock.dart     # text/fruit/meat overlay buttons
            ├── variation_chooser.dart  # "choose the exact item" (on camera)
            ├── price_compare_overlay.dart  # logo + count-up price + distance
            ├── location_permission_overlay.dart
            └── brand_logo.dart         # vector brand marks
```

## What an external agent should touch

| Want to change | File |
| --- | --- |
| Prices / stores / distances | `data/stores_catalog.dart` |
| Dictionary entries & locales | `data/grocery_dictionary.dart` |
| Mock latency (the "3 s" feel) | `providers/mock_grocery_provider.dart` |
| Detection result (text blocks) | `providers/mock_grocery_provider.dart` → `scanText` |
| Overlay look & animations | `widgets/price_compare_overlay.dart` |
| Camera scene objects | `widgets/scene_painters.dart` |
| Flow/timing/state machine | `features/grocery_scan/grocery_scan_page.dart` |

## Convention notes

- The feature is UI-only: `MockGroceryProvider` is the contract. A real
  implementation (camera plugin, ML Kit, price API) only needs to satisfy the
  same method signatures.
- No `pumpAndSettle` in widget tests — the scan-line animation repeats
  forever; tests pump explicit durations against provider timings.
- Toasts are pinned `topCenter` so they never cover the shutter or the price
  overlay (shadcn default is bottom-right).
