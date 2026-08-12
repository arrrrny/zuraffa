import 'package:flutter/material.dart';

/// Price that counts up from $0.00 — the little "wow" of a price reveal.
///
/// Shared by the on-camera price overlay and the chooser's inline prices so
/// the count-up animation is consistent everywhere.
class CountUpPrice extends StatelessWidget {
  const CountUpPrice({
    super.key,
    required this.price,
    required this.color,
    this.fontSize = 18,
  });

  final double price;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: price),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        '\$${value.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
