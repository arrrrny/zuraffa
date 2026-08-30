/// LoadingIndicator (fixture for spec 043) — used by the settings page only;
/// product/profile slices must NOT include it (US1-S1, US1-S4).
library;

import 'package:flutter/material.dart';

/// Centered progress spinner.
class LoadingIndicator extends StatelessWidget {
  /// Creates the indicator.
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
