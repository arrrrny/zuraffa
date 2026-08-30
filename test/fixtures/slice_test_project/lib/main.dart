/// ZikZak app bootstrap (fixture for spec 043) — the full-project entry point
/// that slices replace with a generated `main_slice.dart`.
library;

import 'package:flutter/material.dart';

import 'package:zik_zak/src/di/index.dart';
import 'package:zik_zak/src/presentation/pages/product/product_view.dart';

/// Runs the app.
void main() {
  setupDependencies();
  runApp(const ZikZakApp());
}

/// Root widget.
class ZikZakApp extends StatelessWidget {
  /// Creates the app.
  const ZikZakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'ZikZak', home: ProductView());
  }
}
