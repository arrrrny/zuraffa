import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../models/detections.dart';
import 'scene_geometry.dart';

/// Highlight HUD layered over the viewfinder while a detection is in flight.
///
/// Text mode draws a box per detected block (the primary — largest — block
/// gets corner brackets, a glow and a label chip). Object mode draws a single
/// box + confidence chip around the framed item.
class DetectionHud extends StatelessWidget {
  const DetectionHud({
    super.key,
    required this.size,
    this.textResult,
    this.objectResult,
  });

  final Size size;
  final TextDetectionResult? textResult;
  final ObjectDetectionResult? objectResult;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final primary = shad.colorScheme.primary;

    final children = <Widget>[];

    if (textResult != null) {
      final blocks = textResult!.blocks;
      final primaryBlock = textResult!.primary;
      final tagRect = SceneGeometry.tagRect(size);

      // Secondary blocks — faint boxes (position derived per block index).
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        if (identical(block, primaryBlock)) continue;
        final offset = tagRect.height * (0.34 + i * 0.16);
        final rect = Rect.fromLTWH(
          tagRect.left + tagRect.width * (0.05 + i * 0.02),
          tagRect.top + offset,
          tagRect.width * (0.62 - i * 0.08),
          tagRect.height * 0.13,
        );
        children.add(_DetectBox(rect: rect, subtle: true));
      }

      // Primary block — the largest single text ("Heirloom Tomatoes").
      children.add(
        _PrimaryBox(
          rect: Rect.fromLTWH(
            tagRect.left + tagRect.width * 0.04,
            tagRect.top + tagRect.height * 0.28,
            tagRect.width * 0.55,
            tagRect.height * 0.26,
          ),
          label: '${primaryBlock.text} · ${(primaryBlock.confidence * 100).round()}%',
          color: primary,
        ),
      );
    }

    if (objectResult != null) {
      final rect = SceneGeometry.objectRect(size);
      children.add(
        _PrimaryBox(
          rect: Rect.fromLTWH(
            rect.left - rect.width * 0.10,
            rect.top - rect.height * 0.16,
            rect.width * 1.20,
            rect.height * 1.30,
          ),
          label:
              '${objectResult!.item.name} · ${(objectResult!.confidence * 100).round()}%',
          color: primary,
        ),
      );
    }

    return IgnorePointer(child: Stack(children: children));
  }
}

/// Faint box for non-primary text blocks.
class _DetectBox extends StatelessWidget {
  const _DetectBox({required this.rect, this.subtle = false});

  final Rect rect;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final primary = ShadTheme.of(context).colorScheme.primary;
    return Positioned.fromRect(
      rect: rect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => Opacity(
          opacity: 0.55 * v,
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: primary.withValues(alpha: subtle ? 0.35 : 0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: primary.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }
}

/// Primary highlighted box: corner brackets, glow and a floating label chip.
class _PrimaryBox extends StatelessWidget {
  const _PrimaryBox({
    required this.rect,
    required this.label,
    required this.color,
  });

  final Rect rect;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            for (final align in const [
              Alignment.topLeft,
              Alignment.topRight,
              Alignment.bottomLeft,
              Alignment.bottomRight,
            ])
              Align(
                alignment: align,
                child: _HudCorner(align: align, color: color),
              ),
            // Floating label chip above the box.
            Positioned(
              top: -30,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudCorner extends StatelessWidget {
  const _HudCorner({required this.align, required this.color});

  final Alignment align;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = 14.0;
    return Padding(
      padding: EdgeInsets.only(
        top: align.y < 0 ? 3 : 0,
        bottom: align.y > 0 ? 3 : 0,
        left: align.x < 0 ? 3 : 0,
        right: align.x > 0 ? 3 : 0,
      ),
      child: CustomPaint(
        size: const Size(14, 14),
        painter: _HudCornerPainter(
          color: color,
          flipX: align.x > 0,
          flipY: align.y > 0,
          len: l,
        ),
      ),
    );
  }
}

class _HudCornerPainter extends CustomPainter {
  const _HudCornerPainter({
    required this.color,
    required this.flipX,
    required this.flipY,
    required this.len,
  });

  final Color color;
  final bool flipX;
  final bool flipY;
  final double len;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.translate(flipX ? size.width : 0, flipY ? size.height : 0);
    canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
    final path = Path()
      ..moveTo(0, len)
      ..lineTo(0, 4)
      ..quadraticBezierTo(0, 0, 4, 0)
      ..lineTo(len, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HudCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
