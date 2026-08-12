import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/grocery_dictionary.dart';
import '../../../models/grocery_item.dart';
import '../../../models/store_offer.dart';
import '../../../theme/app_theme.dart';
import 'brand_logo.dart';
import 'count_up_price.dart';

/// On-camera "approve the exact item" chooser (object detection edge case).
///
/// Object detection can only say "tomato" — the embedded localized dictionary
/// knows the store may sell `Tomatoes`, `Organic Tomatoes` or
/// `Heirloom Tomatoes`. When more than one variant exists the customer picks
/// one right here, WITHOUT ever leaving the camera page.
///
/// When the dictionary has a single variant (e.g. cantaloupe) the page skips
/// this widget entirely.
///
/// While the chooser is up, prices are pre-fetched for EVERY variant
/// ([offersByVariantId]); each option shows its best in-store price as soon
/// as it lands (spinner while looking), and picking an already-priced variant
/// reveals the comparison instantly.
class VariationChooser extends StatefulWidget {
  const VariationChooser({
    super.key,
    required this.detected,
    required this.variants,
    required this.offersByVariantId,
    this.onSelected,
    this.onDismiss,
  });

  /// What object detection found (baseline variant, e.g. "Tomatoes").
  final GroceryItem detected;

  /// Candidate display variants from the embedded dictionary.
  final List<GroceryItem> variants;

  /// Pre-fetched best offers per variant id; `null` = comparison in flight,
  /// missing = not started yet.
  final Map<String, List<StoreOffer>?> offersByVariantId;

  final ValueChanged<GroceryItem>? onSelected;
  final VoidCallback? onDismiss;

  @override
  State<VariationChooser> createState() => _VariationChooserState();
}

class _VariationChooserState extends State<VariationChooser> {
  GroceryItem? _picked;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: AppTheme.backgroundRaised.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: shad.colorScheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.badgeCheck,
                    size: 18,
                    color: shad.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Choose the exact item',
                    style: TextStyle(
                      color: shad.colorScheme.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onDismiss,
                    icon: Icon(
                      LucideIcons.x,
                      size: 16,
                      color: shad.colorScheme.mutedForeground,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Object detection found "${widget.detected.name}" — '
                'pick the closest match from the embedded grocery dictionary.',
                style: TextStyle(
                  color: shad.colorScheme.mutedForeground,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              for (final (i, variant) in widget.variants.indexed) ...[
                _VariantRow(
                  variant: variant,
                  highlighted: _picked?.id == variant.id,
                  // Pre-fetched best offer while the chooser is up; null →
                  // still looking. Missing → comparison not started.
                  bestOffer: widget.offersByVariantId[variant.id],
                  onTap: () {
                    setState(() => _picked = variant);
                    widget.onSelected?.call(variant);
                  },
                ),
                if (i != widget.variants.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    LucideIcons.bookOpen,
                    size: 13,
                    color: shad.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dictionary: ${GroceryDictionary.defaultLocale} · embedded, '
                    '${widget.variants.length} variant${widget.variants.length == 1 ? '' : 's'}',
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
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.variant,
    required this.highlighted,
    required this.onTap,
    this.bestOffer,
  });

  final GroceryItem variant;
  final bool highlighted;
  final VoidCallback onTap;

  /// Pre-fetched best offer (cheapest first). `null` = comparison in flight.
  final List<StoreOffer>? bestOffer;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: highlighted
              ? shad.colorScheme.primary.withValues(alpha: 0.14)
              : shad.colorScheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? shad.colorScheme.primary
                : shad.colorScheme.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlighted
                    ? shad.colorScheme.primary
                    : Colors.transparent,
                border: Border.all(
                  color: highlighted
                      ? shad.colorScheme.primary
                      : shad.colorScheme.mutedForeground,
                  width: 1.6,
                ),
              ),
              child: highlighted
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                variant.name,
                style: TextStyle(
                  color: shad.colorScheme.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (variant.isOrganic) ...[
              ShadBadge(
                backgroundColor: shad.colorScheme.primary.withValues(
                  alpha: 0.16,
                ),
                child: Text(
                  'ORGANIC',
                  style: TextStyle(
                    color: shad.colorScheme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Live best price while the customer decides.
            if (bestOffer != null && bestOffer!.isNotEmpty)
              _BestPriceLabel(offer: bestOffer!.first)
            else
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "from $X.XX · Store" — the cheapest in-store offer for this variant, with
/// the store's brand logo and the same count-up animation as the price
/// overlay.
class _BestPriceLabel extends StatelessWidget {
  const _BestPriceLabel({required this.offer});

  final StoreOffer offer;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(brand: offer.brand, size: 16),
            const SizedBox(width: 5),
            Text(
              offer.brand.displayName,
              style: TextStyle(
                color: shad.colorScheme.mutedForeground,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'from ',
              style: TextStyle(
                color: shad.colorScheme.mutedForeground,
                fontSize: 10,
              ),
            ),
            CountUpPrice(
              price: offer.price,
              color: shad.colorScheme.primary,
              fontSize: 13,
            ),
          ],
        ),
      ],
    );
  }
}
