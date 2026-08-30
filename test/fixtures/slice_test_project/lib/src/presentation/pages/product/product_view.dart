/// ProductView (fixture for spec 043) — imports the shared widget barrel with
/// a `show` clause so barrel resolution only pulls PrimaryButton (US1-S4).
library;

import 'package:flutter/material.dart';

import '../../widgets/index.dart' show PrimaryButton;
import 'product_controller.dart';
import 'product_state.dart';

/// The product page.
class ProductView extends StatelessWidget {
  /// Creates the view.
  const ProductView({super.key, this.productId = 'p-1'});

  /// Product to display.
  final String productId;

  @override
  Widget build(BuildContext context) {
    final controller = ProductController();
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: Center(
        child: PrimaryButton(
          label: 'Reload $productId',
          onPressed: () => controller.load(productId),
        ),
      ),
    );
  }
}
