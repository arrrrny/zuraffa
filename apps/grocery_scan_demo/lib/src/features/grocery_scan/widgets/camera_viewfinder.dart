import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/scan_mode.dart';
import 'scene_geometry.dart';
import 'scene_painters.dart';

/// Mock camera viewfinder.
///
/// Renders the fake store scene (shelf backdrop + shelf tag / produce object /
/// barcode) and hosts the object gestures (tap to cycle demo item, long-press
/// to hold-and-scan). The detection HUD and overlays live *above* this widget
/// in the page stack, aligned through [SceneGeometry].
class CameraViewfinder extends StatefulWidget {
  const CameraViewfinder({
    super.key,
    required this.mode,
    required this.objectSeed,
    required this.scanning,
    this.holdProgress,
    this.onObjectTap,
    this.onHoldStart,
    this.onHoldComplete,
    this.onHoldCancel,
  });

  final ScanMode mode;

  /// Which object is framed (produce/meat modes): tomato|cantaloupe|avocado|
  /// steak|chicken.
  final String objectSeed;

  /// Whether the scanning animation is active (barcode + detection phases).
  final bool scanning;

  /// 0..1 hold progress — ring rendered around the framed object.
  final double? holdProgress;

  final VoidCallback? onObjectTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldComplete;
  final VoidCallback? onHoldCancel;

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanline =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  @override
  void dispose() {
    _scanline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return AnimatedBuilder(
            animation: _scanline,
            builder: (context, _) {
              final drift = _scanline.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _BackdropPainter(drift: drift),
                  ),
                  _buildScene(size),
                  if (widget.scanning &&
                      (widget.mode == ScanMode.barcode ||
                          widget.mode == ScanMode.text))
                    _ScanLine(
                      y: SceneGeometry.scanLineY(size, drift),
                      width: size.width,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScene(Size size) {
    switch (widget.mode) {
      case ScanMode.barcode:
        return _BarcodeScene(size: size);
      case ScanMode.text:
        return _TagScene(size: size);
      case ScanMode.produce:
      case ScanMode.meat:
        return _ObjectScene(
          size: size,
          seed: widget.objectSeed,
          holdProgress: widget.holdProgress,
          onTap: widget.onObjectTap,
          onHoldStart: widget.onHoldStart,
          onHoldComplete: widget.onHoldComplete,
          onHoldCancel: widget.onHoldCancel,
        );
      case ScanMode.ingredients:
        return const _IngredientsScene();
    }
  }
}

/// Mock barcode block with corner brackets.
class _BarcodeScene extends StatelessWidget {
  const _BarcodeScene({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final rect = SceneGeometry.barcodeRect(size);
    final primary = ShadTheme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              painter: _BarcodePainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        for (final align in const [
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ])
          Positioned.fromRect(
            rect: rect,
            child: Align(
              alignment: align,
              child: _CornerBracket(align: align, color: primary),
            ),
          ),
      ],
    );
  }
}

/// Store shelf tag ("Heirloom Tomatoes") that text detection reads.
class _TagScene extends StatelessWidget {
  const _TagScene({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final rect = SceneGeometry.tagRect(size);
    final shad = ShadTheme.of(context);
    return Positioned.fromRect(
      rect: rect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: rect.width * 0.05,
            vertical: rect.height * 0.06,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // Fixed-height rows + FittedBox: the tag can never overflow its
          // rect on any screen size (the previous font-size scaling summed
          // slightly over and RenderFlex overflowed by ~13 px).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Store strip.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: shad.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FARM FRESH',
                      style: TextStyle(
                        color: shad.colorScheme.primaryForeground,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'PRODUCE DEPT',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 8,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Primary line — the LARGEST text block the scanner reads.
              _TagLine(
                height: rect.height * 0.26,
                text: 'Heirloom Tomatoes',
                weight: FontWeight.w800,
                color: const Color(0xFF111814),
              ),
              _TagLine(
                height: rect.height * 0.14,
                text: 'Certified Organic',
                weight: FontWeight.w700,
                color: const Color(0xFF3E7A33),
              ),
              _TagLine(
                height: rect.height * 0.11,
                text: 'Product of USA · Net Wt 1 lb',
                weight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
              // Mini barcode strip.
              SizedBox(
                height: rect.height * 0.16,
                width: rect.width * 0.5,
                child: CustomPaint(painter: _BarcodePainter(dark: true)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shelf-tag text row that scales down (never overflows) its slot.
class _TagLine extends StatelessWidget {
  const _TagLine({
    required this.height,
    required this.text,
    required this.weight,
    required this.color,
  });

  final double height;
  final String text;
  final FontWeight weight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 100,
            fontWeight: weight,
            height: 1.05,
          ),
        ),
      ),
    );
  }
}

/// Produce / meat object with hold-to-scan interaction.
/// Mock package back with the ingredient list (stethoscope mode) — the
/// customer frames this and captures.
class _IngredientsScene extends StatelessWidget {
  const _IngredientsScene();

  static const _ingredientLines = [
    'Whole Grain Oats',
    'Wheat Flour',
    'Honey',
    'Canola Oil',
    'Brown Sugar',
    'Barley Malt',
    'Sea Salt, Cinnamon',
  ];

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final size = MediaQuery.of(context).size;
    final rect = SceneGeometry.ingredientsRect(size);
    return Positioned.fromRect(
      rect: rect,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: rect.width * 0.06,
            vertical: rect.height * 0.05,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand strip.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: shad.colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MORNING HARVEST',
                      style: TextStyle(
                        color: shad.colorScheme.primaryForeground,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    LucideIcons.stethoscope,
                    size: 14,
                    color: shad.colorScheme.muted,
                  ),
                ],
              ),
              // Product name.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Honey Oat Granola',
                  style: TextStyle(
                    color: shad.colorScheme.foreground,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // INGREDIENTS label.
              Text(
                'INGREDIENTS',
                style: TextStyle(
                  color: shad.colorScheme.mutedForeground,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              // Tiny ingredient lines (mocked list).
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _ingredientLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: shad.colorScheme.foreground
                              .withValues(alpha: 0.75),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
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

class _ObjectScene extends StatelessWidget {
  const _ObjectScene({
    required this.size,
    required this.seed,
    this.holdProgress,
    this.onTap,
    this.onHoldStart,
    this.onHoldComplete,
    this.onHoldCancel,
  });

  final Size size;
  final String seed;
  final double? holdProgress;
  final VoidCallback? onTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldComplete;
  final VoidCallback? onHoldCancel;

  @override
  Widget build(BuildContext context) {
    final rect = SceneGeometry.objectRect(size);
    final shad = ShadTheme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (_) => onHoldStart?.call(),
      onLongPressEnd: (_) => onHoldComplete?.call(),
      onLongPressCancel: onHoldCancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fromRect(
            rect: rect,
            child: CustomPaint(
              painter: _ObjectPainter(seed: seed),
              child: const SizedBox.expand(),
            ),
          ),
          // Glow under the object.
          Positioned(
            left: rect.center.dx - rect.width * 0.32,
            top: rect.bottom - rect.height * 0.10,
            child: Container(
              width: rect.width * 0.64,
              height: rect.height * 0.18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rect.width),
                gradient: RadialGradient(
                  colors: [
                    shad.colorScheme.primary.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Hold ring (fills while long-pressing).
          if (holdProgress != null)
            Positioned.fromRect(
              rect: Rect.fromCircle(
                center: rect.center,
                radius: rect.shortestSide * 0.62,
              ),
              child: CustomPaint(
                painter: _HoldRingPainter(
                  progress: holdProgress!,
                  color: shad.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small painters
// ---------------------------------------------------------------------------

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.drift});

  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, ScenePainters.backdropPaint());
    ScenePainters.paintBackdrop(canvas, size, drift: drift);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) =>
      oldDelegate.drift != drift;
}

class _ObjectPainter extends CustomPainter {
  const _ObjectPainter({required this.seed});

  final String seed;

  @override
  void paint(Canvas canvas, Size size) =>
      ScenePainters.paintObject(canvas, size, seed: seed);

  @override
  bool shouldRepaint(_ObjectPainter oldDelegate) => oldDelegate.seed != seed;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter({this.dark = false});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (dark) {
      // Dark ink bars for the shelf tag.
      final paint = Paint()..color = const Color(0xFF222B26);
      var x = 0.0;
      var i = 0;
      while (x < size.width) {
        final w = (i % 4 == 0) ? 2.2 : 1.0;
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
        x += w + 1.6;
        i++;
      }
    } else {
      ScenePainters.paintBarcode(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.dark != dark;
}

/// Animated horizontal scan line.
class _ScanLine extends StatelessWidget {
  const _ScanLine({required this.y, required this.width});

  final double y;
  final double width;

  @override
  Widget build(BuildContext context) {
    final primary = ShadTheme.of(context).colorScheme.primary;
    return Positioned(
      top: y,
      left: 0,
      child: Container(
        width: width,
        height: 2.4,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              primary.withValues(alpha: 0.95),
              Colors.transparent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner brackets drawn around the barcode target.
class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.align, required this.color});

  final Alignment align;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const len = 26.0;
    // Flip the L-bracket per corner.
    final start = Offset(
      align.x < 0 ? 0 : -len,
      align.y < 0 ? 0 : -len,
    );
    return CustomPaint(
      size: const Size(len, len),
      painter: _CornerBracketPainter(color: color, start: start),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  const _CornerBracketPainter({required this.color, required this.start});

  final Color color;
  final Offset start;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final s = start;
    final path = Path()
      ..moveTo(s.dx, s.dy + 18)
      ..lineTo(s.dx, s.dy + 6)
      ..quadraticBezierTo(s.dx, s.dy, s.dx + 6, s.dy)
      ..lineTo(s.dx + 18, s.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.start != start;
}

/// Circular hold progress ring around the framed object.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
