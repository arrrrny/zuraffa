import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/store_offer.dart';

/// Stylized brand mark for a [StoreBrand].
///
/// Vector-drawn so the demo needs no image assets. Walmart gets its signature
/// "spark" sunburst, the rest get clean letter marks on their brand color.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, required this.brand, this.size = 40});

  final StoreBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brand.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: brand.color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: brand == StoreBrand.walmart
          ? CustomPaint(
              size: Size.square(size * 0.78),
              painter: _WalmartSparkPainter(),
            )
          : Text(
              brand.name[0],
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.46,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
    );
  }
}

/// Walmart's "spark" — a sunburst of 8 alternating rays inside a circle.
class _WalmartSparkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    final ray = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = (i.isEven ? r * 0.30 : r * 0.52);
      final outer = r * 0.96;
      final dir = Offset(math.cos(angle), math.sin(angle));
      ray.strokeWidth = i.isEven ? r * 0.30 : r * 0.17;
      canvas.drawLine(center + dir * inner, center + dir * outer, ray);
    }
  }

  @override
  bool shouldRepaint(_WalmartSparkPainter oldDelegate) => false;
}
