import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../models/grocery_item.dart';
import '../../../models/store_offer.dart';
import '../../../theme/app_theme.dart';
import 'brand_logo.dart';
import 'count_up_price.dart';

/// On-camera price comparison overlay.
///
/// Rendered directly on top of the camera page (the customer NEVER leaves the
/// viewfinder while prices are compared): glass panel, staggered entry, count-
/// up prices, brand logos and the nearest-store distance.
class PriceCompareOverlay extends StatefulWidget {
  const PriceCompareOverlay({
    super.key,
    required this.item,
    required this.offers,
    required this.locationLabel,
    this.onClose,
    this.onRescan,
  });

  final GroceryItem item;

  /// Ranked offers (cheapest first).
  final List<StoreOffer> offers;

  final String locationLabel;
  final VoidCallback? onClose;
  final VoidCallback? onRescan;

  @override
  State<PriceCompareOverlay> createState() => _PriceCompareOverlayState();
}

class _PriceCompareOverlayState extends State<PriceCompareOverlay> {
  bool _expanded = false;

  /// Two always-visible rows; the rest expand on tap.
  List<StoreOffer> get _visible =>
      _expanded ? widget.offers : widget.offers.take(2).toList();

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final best = widget.offers.isEmpty ? null : widget.offers.first;
    final extras = widget.offers.length - 2;
    final nearest = widget.offers.isEmpty
        ? null
        : widget.offers
            .where((o) => o.distanceMiles != null)
            .reduce((a, b) =>
                (a.distanceMiles ?? 0) <= (b.distanceMiles ?? 0) ? a : b);

    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 40),
            child: child,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundRaised.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: shad.colorScheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: shad.colorScheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Eyebrow + item name.
              Row(
                children: [
                  ShadBadge(
                    backgroundColor: shad.colorScheme.primary.withValues(
                      alpha: 0.14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.badgeDollarSign,
                          size: 11,
                          color: shad.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'IN-STORE PRICE MATCH',
                          style: TextStyle(
                            color: shad.colorScheme.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      LucideIcons.x,
                      size: 17,
                      color: shad.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
              Text(
                widget.item.name,
                style: TextStyle(
                  color: shad.colorScheme.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              // Location chip — nearest store distance, on camera.
              Row(
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    size: 13,
                    color: shad.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${widget.locationLabel}'
                      '${nearest == null ? '' : ' · ${nearest.distanceLabel} to ${nearest.brand.displayName}'}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: shad.colorScheme.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Store offer rows, staggered in.
              if (widget.offers.isEmpty)
                const _ComparingSkeleton()
              else
                for (final (i, offer) in _visible.indexed)
                  _OfferRow(
                    offer: offer,
                    index: i,
                    isBest: offer.isBestPrice && best != null,
                  ),
              // Expandable "more stores" — still on the camera, never a sheet.
              if (extras > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 14,
                      ),
                      label: Text(
                        _expanded
                            ? 'Show fewer stores'
                            : 'View $extras more stores nearby',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: shad.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              // Footer actions.
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: widget.onRescan,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.rotateCw, size: 14),
                          SizedBox(width: 6),
                          Text('Re-scan'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: widget.onClose,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.eye, size: 14),
                          SizedBox(width: 6),
                          Text('Back to camera'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One store offer row: logo + name + distance · price with count-up.
class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.index,
    required this.isBest,
  });

  final StoreOffer offer;
  final int index;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 110),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                BrandLogo(brand: offer.brand, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            offer.brand.displayName,
                            style: TextStyle(
                              color: shad.colorScheme.foreground,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isBest)
                            ShadBadge(
                              backgroundColor: shad.colorScheme.primary,
                              child: const Text(
                                'BEST',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            offer.distanceMiles != null
                                ? LucideIcons.navigation2
                                : LucideIcons.truck,
                            size: 11,
                            color: shad.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            offer.distanceMiles != null
                                ? '${offer.distanceLabel} away'
                                : 'Ship to home',
                            style: TextStyle(
                              color: shad.colorScheme.mutedForeground,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CountUpPrice(
                      price: offer.price,
                      color: isBest
                          ? shad.colorScheme.primary
                          : shad.colorScheme.foreground,
                    ),
                    Text(
                      offer.perUnitLabel,
                      style: TextStyle(
                        color: shad.colorScheme.mutedForeground,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder shown while the (mock) comparison is in flight.
class _ComparingSkeleton extends StatelessWidget {
  const _ComparingSkeleton();

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                _PulseBox(
                  size: const Size(38, 38),
                  radius: 19,
                  color: shad.colorScheme.border,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PulseBox(
                        size: Size(110 + i * 30, 13),
                        radius: 6,
                        color: shad.colorScheme.border,
                      ),
                      const SizedBox(height: 7),
                      _PulseBox(
                        size: Size(70, 10),
                        radius: 5,
                        color: shad.colorScheme.border.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
                _PulseBox(
                  size: const Size(64, 18),
                  radius: 8,
                  color: shad.colorScheme.border,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Soft pulsing block used by [_ComparingSkeleton].
class _PulseBox extends StatefulWidget {
  const _PulseBox({required this.size, required this.radius, required this.color});

  final Size size;
  final double radius;
  final Color color;

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.45).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size.width,
        height: widget.size.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
