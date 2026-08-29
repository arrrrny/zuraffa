/// ProductController (fixture for spec 043).
library;

import 'product_presenter.dart';
import 'product_state.dart';

/// Drives the product page.
class ProductController {
  /// Creates the controller.
  ProductController([ProductPresenter? presenter])
    : _presenter = presenter ?? ProductPresenter();

  final ProductPresenter _presenter;

  /// Current state.
  ProductState state = const ProductState();

  /// Loads the product and updates [state].
  Future<void> load(String id) async {
    state = await _presenter.loadProduct(id);
  }
}
