import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../models/ingredients_analysis.dart';
import '../../../theme/app_theme.dart';

/// Verdict / score colors — red (contains), amber (may contain), green
/// (gluten-free). Scores reuse the same health scale.
const _kDanger = Color(0xFFF87171);
const _kCaution = Color(0xFFFBBF24);
const _kGood = AppTheme.primary;

/// On-camera ingredient check overlay (stethoscope mode).
///
/// Rendered directly on top of the camera page — the customer never leaves
/// the viewfinder while the ingredient list is checked. Dark glass panel
/// with a staggered entry (same language as the price overlay): gluten
/// verdict, health nutrition score ring, factor breakdown and the
/// ingredient list with gluten sources flagged.
class IngredientsOverlay extends StatelessWidget {
  const IngredientsOverlay({
    super.key,
    required this.result,
    this.onClose,
    this.onRescan,
  });

  final IngredientsAnalysis result;
  final VoidCallback? onClose;
  final VoidCallback? onRescan;

  Color get _verdictColor => switch (result.verdict) {
        GlutenVerdict.contains => _kDanger,
        GlutenVerdict.mayContain => _kCaution,
        GlutenVerdict.free => _kGood,
      };

  IconData get _verdictIcon => switch (result.verdict) {
        GlutenVerdict.contains => LucideIcons.wheatOff,
        GlutenVerdict.mayContain => LucideIcons.wheat,
        GlutenVerdict.free => LucideIcons.badgeCheck,
      };

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final verdictColor = _verdictColor;
    final verdictIcon = _verdictIcon;

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
                  decoration: BoxDecoration(
                    color: shad.colorScheme.mutedForeground
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Header: mode + product.
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: verdictColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: verdictColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      LucideIcons.stethoscope,
                      size: 17,
                      color: verdictColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INGREDIENT CHECK',
                          style: TextStyle(
                            color: shad.colorScheme.mutedForeground,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: shad.colorScheme.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          result.brand,
                          style: TextStyle(
                            color: shad.colorScheme.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Gluten verdict pill.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: verdictColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(verdictIcon, size: 16, color: verdictColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.verdict.label,
                        style: TextStyle(
                          color: verdictColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (result.glutenSources.isNotEmpty)
                      Text(
                        result.glutenSources.length == 1
                            ? '1 gluten source'
                            : '${result.glutenSources.length} gluten '
                                'sources',
                        style: TextStyle(
                          color: verdictColor.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Nutrition score ring + factor breakdown.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ScoreRing(
                    score: result.nutritionScore,
                    color: _scoreColor(result.nutritionScore),
                    size: 88,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (final factor in result.factors)
                          _FactorRow(factor: factor),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Ingredient list with gluten sources flagged.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ingredient in result.ingredients)
                    _IngredientChip(
                      label: ingredient,
                      flagged: result.glutenSources.contains(ingredient),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Actions — same layout as the price overlay.
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: onRescan,
                      child: const Text('Re-scan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: onClose,
                      child: const Text('Back to camera'),
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

  static Color _scoreColor(int score) => switch (score) {
        >= 70 => _kGood,
        >= 50 => _kCaution,
        _ => _kDanger,
      };
}

/// Circular 0..100 health score with the number in the middle.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({
    required this.score,
    required this.color,
    required this.size,
  });

  final int score;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                progress: score / 100,
                color: color,
                strokeWidth: 7,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'nutrition',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                'score',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final track = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// One factor row: label, value and a health bar.
class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final NutritionFactor factor;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final color =
        factor.isBeneficial ? _kGood : IngredientsOverlay._scoreColor(factor.score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              factor.label,
              style: TextStyle(
                color: shad.colorScheme.mutedForeground,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              factor.value,
              style: TextStyle(
                color: shad.colorScheme.foreground,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: color.withValues(alpha: 0.15),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (factor.score / 100).clamp(0.0, 1.0),
                  child: Container(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ingredient chip — gluten sources get a red border + wheat-off mark.
class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label, required this.flagged});

  final String label;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final color = flagged ? _kDanger : shad.colorScheme.mutedForeground;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: flagged
            ? _kDanger.withValues(alpha: 0.1)
            : shad.colorScheme.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: flagged
              ? _kDanger.withValues(alpha: 0.55)
              : shad.colorScheme.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flagged) ...[
            Icon(LucideIcons.wheatOff, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: flagged
                  ? _kDanger
                  : shad.colorScheme.foreground.withValues(alpha: 0.85),
              fontSize: 10.5,
              fontWeight: flagged ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
