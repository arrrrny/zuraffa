/// PrimaryButton (fixture for spec 043) — used by BOTH the product and
/// profile views, so slices classify it `shared` (FR-010, US1-S2).
library;

import 'package:flutter/material.dart';

/// The app's primary action button.
class PrimaryButton extends StatelessWidget {
  /// Creates the button.
  const PrimaryButton({super.key, required this.label, this.onPressed});

  /// Button text.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(onPressed: onPressed, child: Text(label));
  }
}
