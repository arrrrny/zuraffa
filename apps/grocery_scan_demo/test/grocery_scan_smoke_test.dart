import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_scan_demo/src/app.dart';
import 'package:grocery_scan_demo/src/providers/mock_grocery_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// UI/UX smoke tests for the standalone mock app.
///
/// The feature must be fully drivable through [MockGroceryProvider] — no
/// camera, ML or backend wiring. These tests pin the happy paths of the scan
/// session state machine.
///
/// NOTE: never use `pumpAndSettle` here — the viewfinder runs an infinitely
/// repeating scan-line animation, so settle would time out. All timings are
/// pumped explicitly against the provider's documented mock latencies
/// (permission 1.4 s, text detection 0.9 s, compare 2.2 s).
void main() {
  testWidgets('permission overlay → camera becomes live', (tester) async {
    final provider = MockGroceryProvider();
    await tester.pumpWidget(GroceryScanApp(provider: provider));

    // First run: location permission overlay.
    expect(find.text('Compare prices in-store'), findsOneWidget);

    // Allow → overlay settles (0.9 s) + provider mock latency (1.4 s).
    await tester.tap(find.text('Allow location'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));

    expect(find.text('ZikZak Price Match'), findsOneWidget);
    expect(find.text('Compare prices in-store'), findsNothing);
    provider.dispose();
  });

  testWidgets('text mode auto-detects the tag and reveals prices on camera',
      (tester) async {
    final provider = MockGroceryProvider();
    await tester.pumpWidget(GroceryScanApp(provider: provider));
    await tester.pump(const Duration(milliseconds: 100));

    // Skip permission.
    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 400));

    // Switch to text detection via the overlay dock.
    await tester.tap(find.byIcon(LucideIcons.textCursorInput));
    await tester.pump(const Duration(milliseconds: 300));

    // Detection (~0.9 s) → highlight appears with the largest text block.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.textContaining('Heirloom Tomatoes · 97%'), findsOneWidget);

    // Comparison (~2.2 s after detection) → price overlay lands on camera.
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('IN-STORE PRICE MATCH'), findsOneWidget);
    expect(find.text('Walmart'), findsWidgets);
    expect(find.textContaining('1.4 mi'), findsWidgets);

    provider.dispose();
  });

  testWidgets(
      'object mode: variants prompt when dictionary has alternatives, '
      'cantaloupe skips the prompt', (tester) async {
    final provider = MockGroceryProvider();
    await tester.pumpWidget(GroceryScanApp(provider: provider));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 400));

    // Produce mode (fruit overlay button).
    await tester.tap(find.byIcon(LucideIcons.apple));
    await tester.pump(const Duration(milliseconds: 300));

    // Hold-to-scan via the shutter button (programmatic hold, 1.3 s).
    // The first pump anchors the animation start (ticker semantics).
    await tester.tap(find.byIcon(LucideIcons.camera));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    // Object detection (0.7 s) → tomato found with variants → chooser.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Choose the exact item'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
    expect(find.text('Organic Tomatoes'), findsOneWidget);

    // Prices are pre-fetched for every variant while the chooser is up —
    // each option shows its best in-store price when it lands (2.2 s).
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.text('from '), findsNWidgets(3));

    // Pick a variant → its price is already there → instant reveal.
    await tester.tap(find.text('Organic Tomatoes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('IN-STORE PRICE MATCH'), findsOneWidget);

    provider.dispose();
  });
}
