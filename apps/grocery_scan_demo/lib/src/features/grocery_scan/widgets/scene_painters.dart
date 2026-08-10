import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom painters for the mock camera scene: store-shelf backdrop, produce
/// and meat objects, and the barcode block. All painters are pure — state and
/// animation live in the widgets that host them.
///
/// Objects are deliberately stylized-but-readable so the demo works on any
/// device without any image assets.
abstract final class ScenePainters {
  ScenePainters._();

  // ---------------------------------------------------------------------------
  // Backdrop — dark in-store shelf with soft bokeh
  // ---------------------------------------------------------------------------

  static Paint backdropPaint() => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF101915),
        Color(0xFF070B09),
        Color(0xFF0A110D),
      ],
      stops: [0.0, 0.55, 1.0],
    ).createShader(const Rect.fromLTWH(0, 0, 1, 1));

  /// Soft shelf shelf-lines + bokeh + vignette.
  static void paintBackdrop(
    Canvas canvas,
    Size size, {
    required double drift,
  }) {
    // Guard: the very first (warm-up) frame can paint with a 0×0 size —
    // `% size.width` would produce NaN and crash the paint.
    if (size.isEmpty) return;

    // Shelf edges (horizon lines).
    final shelfPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1B2621).withValues(alpha: 0.55),
          const Color(0xFF101815).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.52, size.width, 40));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.52, size.width, 40),
      shelfPaint,
    );
    final edgePaint = Paint()
      ..color = const Color(0xFF2A3A32).withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(0, size.height * 0.52),
      Offset(size.width, size.height * 0.52),
      edgePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.70),
      edgePaint..color = const Color(0xFF223029).withValues(alpha: 0.6),
    );

    // Drifting bokeh blobs.
    final rng = math.Random(7);
    final blobPaint = Paint()..color = const Color(0xFF34D399).withValues(alpha: 0.045);
    for (var i = 0; i < 9; i++) {
      final x = (rng.nextDouble() * size.width + drift * 30) % size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final r = 24 + rng.nextDouble() * 56;
      canvas.drawCircle(Offset(x, y), r, blobPaint);
    }

    // Vignette.
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 1.1,
        colors: [
          Colors.transparent,
          const Color(0xFF000000).withValues(alpha: 0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  // ---------------------------------------------------------------------------
  // Produce
  // ---------------------------------------------------------------------------

  static void paintTomato(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Body with radial glow.
    final body = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.2,
        colors: [
          const Color(0xFFF87171).withValues(alpha: 0.9),
          const Color(0xFFDC2626),
          const Color(0xFF991B1B),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, body);

    // Top calyx (green star).
    final calyx = Paint()..color = const Color(0xFF4D7C0F);
    for (var i = 0; i < 5; i++) {
      final angle = math.pi * (0.55 + i * 0.4);
      final tip = center +
          Offset(math.cos(angle), math.sin(angle) * 0.55) * (radius * 1.15);
      canvas.drawLine(center - Offset(0, radius * 0.45), tip, calyx
        ..strokeWidth = radius * 0.22
        ..strokeCap = StrokeCap.round);
    }
    final stem = Paint()
      ..color = const Color(0xFF365314)
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center - Offset(0, radius * 0.4),
      center - Offset(0, radius * 1.25),
      stem,
    );

    // Specular highlight.
    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glint);
  }

  static void paintCantaloupe(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final body = Paint()
      ..shader = RadialGradient(
        center: Alignment(-0.3, -0.35),
        radius: 1.15,
        colors: [
          const Color(0xFFFDE68A),
          const Color(0xFFD9A13B),
          const Color(0xFFB47A22),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, body);

    // Net pattern (the classic rind reticulation).
    final net = Paint()
      ..color = const Color(0xFF9C6F1F).withValues(alpha: 0.55)
      ..strokeWidth = math.max(1.4, radius * 0.045);
    final rng = math.Random(11);
    for (var i = 0; i < 14; i++) {
      final a1 = rng.nextDouble() * math.pi * 2;
      final a2 = a1 + (0.9 + rng.nextDouble()) * 0.9;
      final r1 = radius * (0.25 + rng.nextDouble() * 0.6);
      final r2 = radius * (0.25 + rng.nextDouble() * 0.6);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r1),
        a1,
        a2,
        false,
        net,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r2),
        a1 + 0.6,
        a2,
        false,
        net,
      );
    }

    // Stem scar.
    canvas.drawCircle(
      center - Offset(0, radius * 0.9),
      radius * 0.10,
      Paint()..color = const Color(0xFF7C5A15),
    );

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 0.85,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glint);
  }

  static void paintAvocado(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Pear-ish body.
    final bodyRect = Rect.fromCenter(
      center: center,
      width: radius * 1.55,
      height: radius * 2.0,
    );
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.3,
        colors: [
          const Color(0xFF65A30D),
          const Color(0xFF3F6212),
          const Color(0xFF1F3D0B),
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, body);

    // Skin texture streaks.
    final streak = Paint()
      ..color = const Color(0xFF2F4A0E).withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (var i = -3; i <= 3; i++) {
      final x = center.dx + i * radius * 0.22;
      canvas.drawLine(
        Offset(x, center.dy - radius * 0.75),
        Offset(x + radius * 0.12, center.dy + radius * 0.75),
        streak,
      );
    }

    // Stem.
    final stem = Paint()
      ..color = const Color(0xFF6B4E1D)
      ..strokeWidth = radius * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center - Offset(0, radius * 0.92),
      center - Offset(0, radius * 1.18),
      stem,
    );

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 0.7,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, glint);
  }

  // ---------------------------------------------------------------------------
  // Meat
  // ---------------------------------------------------------------------------

  static void paintSteak(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final bodyRect = Rect.fromCenter(
      center: center,
      width: radius * 2.1,
      height: radius * 1.45,
    );
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.25,
        colors: [
          const Color(0xFFB91C1C),
          const Color(0xFF88130F),
          const Color(0xFF5B0F0B),
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, body);

    // Fat marbling.
    final fat = Paint()
      ..color = const Color(0xFFF6D9B8).withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.2, radius * 0.05)
      ..strokeCap = StrokeCap.round;
    final rng = math.Random(3);
    for (var i = 0; i < 6; i++) {
      final dy = center.dy + (i - 2.5) * radius * 0.22;
      final wiggle = rng.nextDouble();
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - radius * 0.85, dy)
          ..quadraticBezierTo(
            center.dx - radius * 0.2,
            dy - radius * 0.18 * wiggle,
            center.dx + radius * 0.25,
            dy + radius * 0.12,
          )
          ..quadraticBezierTo(
            center.dx + radius * 0.7,
            dy + radius * 0.15,
            center.dx + radius * 0.9,
            dy - radius * 0.05,
          ),
        fat,
      );
    }

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 0.8,
        colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, glint);
  }

  static void paintChicken(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final bodyRect = Rect.fromCenter(
      center: center,
      width: radius * 1.7,
      height: radius * 1.6,
    );
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 1.3,
        colors: [
          const Color(0xFFF4C4A0),
          const Color(0xFFD99372),
          const Color(0xFFB06B52),
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, body);

    // Tender stripes.
    final stripe = Paint()
      ..color = const Color(0xFFE8AC88).withValues(alpha: 0.8)
      ..strokeWidth = math.max(1.2, radius * 0.045);
    for (var i = -2; i <= 2; i++) {
      final x = center.dx + i * radius * 0.22;
      canvas.drawLine(
        Offset(x, center.dy - radius * 0.55),
        Offset(x + radius * 0.08, center.dy + radius * 0.55),
        stripe,
      );
    }

    final glint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 0.75,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(bodyRect);
    canvas.drawOval(bodyRect, glint);
  }

  // ---------------------------------------------------------------------------
  // Barcode
  // ---------------------------------------------------------------------------

  static void paintBarcode(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE8F0EA);
    final rng = math.Random(42);
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final w = (i % 5 == 0) ? 3.0 : 1.0 + rng.nextDouble() * 2.5;
      final h = (i % 7 == 0) ? size.height : size.height * 0.92;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - h, w, h),
        paint..color = const Color(0xFFE8F0EA).withValues(alpha: 0.9),
      );
      x += w + 2.2;
      i++;
    }
    // Start/end guard bars.
    canvas.drawRect(
      Rect.fromLTWH(2, 0, 3, size.height),
      paint..color = const Color(0xFFE8F0EA),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width - 5, 0, 3, size.height),
      paint..color = const Color(0xFFE8F0EA),
    );
  }

  /// Painter used by object modes: dispatches to the right produce/meat art.
  static void paintObject(
    Canvas canvas,
    Size size, {
    required String seed,
  }) {
    switch (seed) {
      case 'tomato':
        paintTomato(canvas, size);
      case 'cantaloupe':
        paintCantaloupe(canvas, size);
      case 'avocado':
        paintAvocado(canvas, size);
      case 'steak':
        paintSteak(canvas, size);
      case 'chicken':
        paintChicken(canvas, size);
      default:
        paintTomato(canvas, size);
    }
  }
}
