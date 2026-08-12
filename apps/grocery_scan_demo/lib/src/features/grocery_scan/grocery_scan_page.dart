import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../providers/mock_grocery_provider.dart';
import '../../providers/mock_grocery_scope.dart';
import '../../theme/app_theme.dart';
import '../../models/detections.dart';
import '../../models/grocery_item.dart';
import '../../models/ingredients_analysis.dart';
import '../../models/store_offer.dart';
import 'models/scan_mode.dart';
import 'widgets/camera_viewfinder.dart';
import 'widgets/detection_hud.dart';
import 'widgets/ingredients_overlay.dart';
import 'widgets/location_permission_overlay.dart';
import 'widgets/price_compare_overlay.dart';
import 'widgets/scan_mode_dock.dart';
import 'widgets/variation_chooser.dart';

/// Lifecycle stages of the price-match camera session.
enum ScanStage {
  /// First run — location permission prompt.
  permission,

  /// Viewfinder live, waiting for input.
  live,

  /// Text/object detection in flight (highlight boxes appear).
  detecting,

  /// Object detection found variants — customer picks the exact item.
  choosing,

  /// Price comparison running / revealed on camera.
  comparing,

  /// Ingredient photo captured — gluten/health analysis in flight.
  ingredientsScanning,
}

/// ZikZak "Grocery Price Match" camera feature.
///
/// The full state machine of the scan session lives here; every visual layer
/// is a separate widget driven by this page's state, so each piece can be
/// iterated on (or replaced by a real ML pipeline) independently.
class GroceryScanPage extends StatefulWidget {
  const GroceryScanPage({super.key});

  @override
  State<GroceryScanPage> createState() => _GroceryScanPageState();
}

class _GroceryScanPageState extends State<GroceryScanPage>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 1300);

  late final MockGroceryProvider _provider;
  late final AnimationController _hold;

  ScanStage _stage = ScanStage.permission;
  ScanMode _mode = ScanMode.barcode;

  /// Cycles the demo object per category — produce: tomato → cantaloupe →
  /// avocado; meat: steak → chicken.
  int _objectIndex = 0;

  /// Generation counter — invalidates in-flight async work on mode switches.
  int _session = 0;

  TextDetectionResult? _textResult;
  ObjectDetectionResult? _objectResult;
  List<GroceryItem>? _variants;
  GroceryItem? _item;
  List<StoreOffer>? _offers;
  IngredientsAnalysis? _ingredientsResult;

  /// Best offers per variant id while the "choose the exact item" screen is
  /// up — prices are pre-fetched for EVERY variant so the customer sees live
  /// numbers next to each option (null value = still looking).
  final Map<String, List<StoreOffer>?> _variantOffers = {};

  bool get _isComparing => _stage == ScanStage.comparing;
  bool get _detecting => _stage == ScanStage.detecting;

  String get _objectSeed => switch (_mode) {
        ScanMode.produce => const ['tomato', 'cantaloupe', 'avocado'][
            _objectIndex % 3],
        ScanMode.meat => const ['steak', 'chicken'][_objectIndex % 2],
        _ => 'tomato',
      };

  @override
  void initState() {
    super.initState();
    // Created eagerly — a `late` controller must not be first touched in
    // dispose(), where the element is already deactivated.
    _hold = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener(_onHoldStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // InheritedWidget lookups are only legal from didChangeDependencies on.
    _provider = MockGroceryScope.of(context);
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _onPermissionResult(bool allow) async {
    if (!allow) {
      setState(() => _stage = ScanStage.live);
      _toast(
        title: 'Location off',
        description: 'You can still scan — store distances are hidden.',
      );
      return;
    }
    final granted = await _provider.requestLocationPermission();
    if (!mounted) return;
    setState(() => _stage = ScanStage.live);
    if (granted) {
      _toast(
        title: 'Location enabled',
        description: 'Showing prices for ${_provider.locationLabel}.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Mode switching
  // ---------------------------------------------------------------------------

  void _enterMode(ScanMode mode) {
    final sameMode = mode == _mode;
    _session++;
    setState(() {
      _mode = mode;
      _stage = ScanStage.live;
      _textResult = null;
      _objectResult = null;
      _variants = null;
      _item = null;
      _offers = null;
      _ingredientsResult = null;
      _variantOffers.clear();
    });
    _hold.reset();

    if (mode == ScanMode.barcode) {
      _toast(
        title: 'Barcode mode',
        description: 'Barcode scanning is mocked in this demo.',
      );
    } else if (sameMode) {
      _rerunCurrentMode();
    } else if (mode == ScanMode.text) {
      // Auto-detect as soon as the camera is pointing at the tag.
      _runTextScan();
    }
  }

  void _rerunCurrentMode() {
    switch (_mode) {
      case ScanMode.barcode:
        break;
      case ScanMode.text:
        _runTextScan();
      case ScanMode.produce:
      case ScanMode.meat:
        _startHold();
      case ScanMode.ingredients:
        _runIngredientsScan();
    }
  }

  // ---------------------------------------------------------------------------
  // Ingredient check flow (stethoscope mode)
  // ---------------------------------------------------------------------------

  /// Captures the ingredient list and runs the gluten/health analysis —
  /// stays on camera, exactly like the price compare.
  Future<void> _runIngredientsScan() async {
    final session = ++_session;
    setState(() {
      _stage = ScanStage.ingredientsScanning;
      _ingredientsResult = null;
      _textResult = null;
      _objectResult = null;
      _item = null;
      _offers = null;
    });

    final result = await _provider.scanIngredients();
    if (!mounted || session != _session || _mode != ScanMode.ingredients) {
      return;
    }
    setState(() {
      _ingredientsResult = result;
      _stage = ScanStage.live;
    });
  }

  void _dismissIngredients() {
    setState(() {
      _ingredientsResult = null;
      _stage = ScanStage.live;
    });
  }

  // ---------------------------------------------------------------------------
  // Text detection flow
  // ---------------------------------------------------------------------------

  Future<void> _runTextScan() async {
    final session = ++_session;
    setState(() {
      _stage = ScanStage.detecting;
      _textResult = null;
      _objectResult = null;
      _item = null;
      _offers = null;
    });

    final result = await _provider.scanText();
    if (!mounted || session != _session || _mode != ScanMode.text) return;
    setState(() {
      _textResult = result;
      _stage = ScanStage.detecting;
    });

    // Highlight first, then compare — price lands ~3 s after the scan starts.
    final item = _provider.itemFromText(result.primary);
    await _compare(item, session);
  }

  // ---------------------------------------------------------------------------
  // Object detection flow
  // ---------------------------------------------------------------------------

  void _onObjectTap() {
    if (_stage != ScanStage.live || !_mode.isObjectMode) return;
    setState(() => _objectIndex++);
    _toast(
      title: 'Now pointing at…',
      description: 'Tap again to cycle demo items. Hold to scan.',
    );
  }

  void _startHold() {
    if (!_mode.isObjectMode || _stage != ScanStage.live) return;
    _hold.forward(from: 0);
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scanObject();
    }
  }

  /// Long-press released early → cancel the hold (unless almost done).
  void _onHoldRelease() {
    if (_hold.value < 0.6) {
      _hold.reset();
    }
  }

  void _onHoldCancel() {
    _hold.reset();
  }

  Future<void> _scanObject() async {
    final session = ++_session;
    setState(() {
      _stage = ScanStage.detecting;
      _textResult = null;
      _objectResult = null;
      _variants = null;
      _item = null;
      _offers = null;
      _variantOffers.clear();
    });

    final result = await _provider.scanObject(
      category: _mode.objectCategory!,
      demoIndex: _objectIndex,
    );
    if (!mounted || session != _session || !_mode.isObjectMode) return;
    setState(() {
      _objectResult = result;
      _stage = ScanStage.detecting;
    });

    final variants = _provider.variantsFor(result.item);
    if (!mounted || session != _session) return;

    if (variants.length <= 1) {
      // No variations (e.g. cantaloupe) → no prompt, straight to prices.
      await _compare(result.item, session);
    } else {
      setState(() {
        _variants = variants;
        _stage = ScanStage.choosing;
      });
      // Pre-fetch prices for EVERY variant while the customer decides —
      // each option shows its best price as it lands, and the chosen one is
      // revealed instantly.
      _prefetchVariantPrices(variants, session);
    }
  }

  /// Fires a price comparison PER variant in parallel and stores the best
  /// offer next to each option. Results are discarded when the session is
  /// invalidated.
  Future<void> _prefetchVariantPrices(
    List<GroceryItem> variants,
    int session,
  ) async {
    for (final variant in variants) {
      setState(() => _variantOffers[variant.id] = null);
      unawaited(_fetchVariantPrice(variant, session));
    }
  }

  Future<void> _fetchVariantPrice(GroceryItem variant, int session) async {
    final offers = await _provider.comparePrices(variant);
    if (!mounted || session != _session) return;
    setState(() => _variantOffers[variant.id] = offers);
  }

  void _onVariantSelected(GroceryItem variant) {
    final session = _session;
    setState(() => _stage = ScanStage.detecting);
    final prefetched = _variantOffers[variant.id];
    if (prefetched != null) {
      // Price already landed while the chooser was up — reveal instantly.
      setState(() {
        _item = variant;
        _offers = prefetched;
        _stage = ScanStage.comparing;
      });
    } else {
      _compare(variant, session);
    }
  }

  void _dismissChooser() {
    setState(() {
      _variants = null;
      _stage = ScanStage.live;
      _objectResult = null;
      _variantOffers.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Price comparison
  // ---------------------------------------------------------------------------

  Future<void> _compare(GroceryItem item, int session) async {
    setState(() {
      _item = item;
      _stage = ScanStage.comparing;
      _offers = null;
    });

    final offers = await _provider.comparePrices(item);
    if (!mounted || session != _session) return;
    setState(() {
      _offers = offers;
      _stage = ScanStage.comparing;
    });
  }

  void _dismissCompare() {
    _session++;
    setState(() {
      _stage = ScanStage.live;
      _textResult = null;
      _objectResult = null;
      _variants = null;
      _item = null;
      _offers = null;
      _variantOffers.clear();
    });
    _hold.reset();
  }

  void _rescan() {
    _dismissCompare();
    _rerunCurrentMode();
  }

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------

  void _toast({required String title, String? description}) {
    ShadToaster.of(context).show(
      ShadToast(
        title: Text(title),
        description: description == null ? null : Text(description),
        // Top-center keeps notifications clear of the shutter and the
        // on-camera price overlay (default is bottom-right).
        alignment: Alignment.topCenter,
      ),
    );
  }

  void _barcodeShutterTap() {
    _toast(
      title: 'Barcode mode is mocked',
      description: 'Flip to Text or Object mode to see price matching.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera feed (mock).
                    CameraViewfinder(
                      mode: _mode,
                      objectSeed: _objectSeed,
                      scanning: _stage == ScanStage.live &&
                          (_mode == ScanMode.barcode || _detecting),
                      holdProgress: _mode.isObjectMode && _hold.isAnimating
                          ? _hold.value
                          : null,
                      onObjectTap: _onObjectTap,
                      onHoldStart: _startHold,
                      onHoldComplete: _onHoldRelease,
                      onHoldCancel: _onHoldCancel,
                    ),

                    // Top gradient + chrome.
                    _TopBar(
                      mode: _mode,
                      stage: _stage,
                      locationLabel: _provider.isLocationGranted
                          ? _provider.locationLabel
                          : null,
                      onBack: () => _toast(
                        title: 'Standalone UI/UX demo',
                        description:
                            'This camera is a self-contained mock — no wiring needed.',
                      ),
                    ),

                    // Mode dock (text / fruit / meat overlay buttons).
                    Positioned(
                      right: 14,
                      top: size.height * 0.30,
                      child: ScanModeDock(
                        activeMode: _mode,
                        enabled: _stage == ScanStage.live ||
                            _stage == ScanStage.detecting,
                        onModeTap: _enterMode,
                      ),
                    ),

                    // Detection highlight boxes.
                    if (_detecting || _stage == ScanStage.comparing)
                      DetectionHud(
                        size: size,
                        textResult: _textResult,
                        objectResult: _objectResult,
                      ),

                    // Bottom gradient + context hint bar.
                    _BottomBar(
                      mode: _mode,
                      stage: _stage,
                      objectSeed: _objectSeed,
                      onShutterTap: switch (_mode) {
                        ScanMode.barcode => _barcodeShutterTap,
                        ScanMode.text => _runTextScan,
                        ScanMode.produce ||
                        ScanMode.meat =>
                          _startHold,
                        ScanMode.ingredients => _runIngredientsScan,
                      },
                    ),

                    // On-camera ingredient check overlay (stethoscope mode).
                    if (_ingredientsResult != null)
                      IngredientsOverlay(
                        result: _ingredientsResult!,
                        onClose: _dismissIngredients,
                        onRescan: _runIngredientsScan,
                      ),

                    // On-camera price compare overlay (never a sheet).
                    if (_isComparing && _item != null)
                      PriceCompareOverlay(
                        item: _item!,
                        offers:
                            _offers ??
                            const [
                              // Skeleton placeholder while comparing.
                            ],
                        locationLabel: _provider.isLocationGranted
                            ? _provider.locationLabel
                            : 'Location off',
                        onClose: _dismissCompare,
                        onRescan: _rescan,
                      ),

                    // On-camera variant chooser (object detection edge case).
                    if (_stage == ScanStage.choosing &&
                        _objectResult != null &&
                        _variants != null)
                      VariationChooser(
                        detected: _objectResult!.item,
                        variants: _variants!,
                        offersByVariantId: _variantOffers,
                        onSelected: _onVariantSelected,
                        onDismiss: _dismissChooser,
                      ),

                    // First-run location permission.
                    if (_stage == ScanStage.permission)
                      LocationPermissionOverlay(onResult: _onPermissionResult),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top chrome
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.stage,
    required this.locationLabel,
    required this.onBack,
  });

  final ScanMode mode;
  final ScanStage stage;
  final String? locationLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return IgnorePointer(
      ignoring: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Back.
              _GlassCircle(
                icon: LucideIcons.arrowLeft,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              // Brand + mode.
              Expanded(
                child: Column(
                  // `min` is CRITICAL: inside the full-width Row this Column
                  // would otherwise expand to the full frame height, making
                  // the top-bar's gradient container full-screen and
                  // swallowing every tap below it.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ZikZak Price Match',
                      style: TextStyle(
                        color: shad.colorScheme.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _StageChip(mode: mode, stage: stage),
                  ],
                ),
              ),
              // Location status.
              if (locationLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: shad.colorScheme.border.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 12,
                        color: shad.colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        locationLabel!,
                        style: TextStyle(
                          color: shad.colorScheme.foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.mode, required this.stage});

  final ScanMode mode;
  final ScanStage stage;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final (label, busy) = switch (stage) {
      ScanStage.detecting => (mode.isObjectMode ? 'Detecting object…' : 'Reading tag…', true),
      ScanStage.choosing => ('Confirm exact item', false),
      ScanStage.comparing => ('Comparing nearby stores…', true),
      _ => (mode.label, false),
    };
    return Row(
      children: [
        if (busy) ...[
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: shad.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: shad.colorScheme.mutedForeground,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom hint bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.mode,
    required this.stage,
    required this.objectSeed,
    required this.onShutterTap,
  });

  final ScanMode mode;
  final ScanStage stage;
  final String objectSeed;
  final VoidCallback onShutterTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final active =
        stage == ScanStage.live || stage == ScanStage.detecting;

    final hint = switch (stage) {
      ScanStage.detecting =>
        mode.isObjectMode ? 'Hold steady — detecting…' : 'Reading the tag…',
      ScanStage.choosing => 'Object found — pick the exact item',
      ScanStage.comparing => 'Prices found — everything stays on camera',
      ScanStage.ingredientsScanning => 'Reading ingredients…',
      _ => mode.hint,
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Row(
          children: [
            // Left zone: demo tip (object mode) or context hint.
            Expanded(
              child: mode.isObjectMode && stage == ScanStage.live
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: shad.colorScheme.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.mousePointerClick,
                            size: 12,
                            color: shad.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Tap item to change it',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: shad.colorScheme.mutedForeground,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      hint,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
            // Shutter / action — centered via a balancing spacer.
            GestureDetector(
              onTap: active ? onShutterTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.96),
                      Colors.white.withValues(alpha: 0.82),
                    ],
                  ),
                  border: Border.all(
                    color: active
                        ? shad.colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  // The stethoscope mode captures the ingredient list —
                  // the shutter keeps the stethoscope identity.
                  mode == ScanMode.ingredients
                      ? LucideIcons.stethoscope
                      : LucideIcons.camera,
                  size: 24,
                  color: AppTheme.background,
                ),
              ),
            ),
            // Balances the shutter so it sits dead-center of the camera:
            // equal flexes on both sides (not a fixed-width spacer, which
            // only works when the left content has a fixed width).
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

/// Small glass circle button used in the top bar.
class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: shad.colorScheme.border.withValues(alpha: 0.8),
          ),
        ),
        child: Icon(icon, size: 17, color: shad.colorScheme.foreground),
      ),
    );
  }
}
