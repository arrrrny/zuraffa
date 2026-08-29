/// SecondaryButton (fixture for spec 043) — used by the settings page only;
/// product/profile slices must NOT include it (US1-S1).
library;

import 'package:flutter/material.dart';

/// The app's secondary action button.
class SecondaryButton extends StatelessWidget {
  /// Creates the button.
  const SecondaryButton({super.key, required this.label, this.onPressed});

  /// Button text.
  final String label;

  /// Tap handler.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
