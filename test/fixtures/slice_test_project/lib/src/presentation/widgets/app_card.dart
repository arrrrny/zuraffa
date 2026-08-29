/// AppCard (fixture for spec 043) — used by the profile view; a barrel import
/// without `show` must still resolve it because profile references it (U14).
library;

import 'package:flutter/material.dart';

/// Rounded card container used across profile screens.
class AppCard extends StatelessWidget {
  /// Creates the card.
  const AppCard({super.key, required this.child});

  /// Card content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: child));
  }
}
