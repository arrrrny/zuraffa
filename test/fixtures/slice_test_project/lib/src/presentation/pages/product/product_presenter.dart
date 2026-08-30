/// ProductPresenter (fixture for spec 043) — resolves its usecases through the
/// service locator (US1-S3, U9-U12), including one nested `registerUseCase`
/// call (U10).
library;

import 'package:get_it/get_it.dart';

import '../../../domain/entities/product/product.dart';
import '../../../domain/usecases/product/get_product_usecase.dart';
import '../../../domain/usecases/product/update_product_usecase.dart';
import '../../../domain/usecases/shared/fetch_settings_usecase.dart';
import 'product_state.dart';

final getIt = GetIt.instance;

/// Presents product data for the view.
class ProductPresenter {
  /// Creates the presenter, resolving usecases via the service locator.
  ProductPresenter() {
    _getProduct = getIt<GetProductUseCase>();
    registerUseCase(getIt<UpdateProductUseCase>());
    _fetchSettings = getIt<FetchSettingsUseCase>();
  }

  late final GetProductUseCase _getProduct;
  late final UpdateProductUseCase _updateProduct;
  late final FetchSettingsUseCase _fetchSettings;

  /// Registers an update usecase obtained by the caller (U10 fixture shape).
  void registerUseCase(UpdateProductUseCase usecase) {
    _updateProduct = usecase;
  }

  /// Loads a product into a state.
  Future<ProductState> loadProduct(String id) async {
    try {
      final product = await _getProduct.execute(id);
      return const ProductState().copyWith(product: product);
    } catch (e) {
      return const ProductState().copyWith(error: e.toString());
    }
  }

  /// Persists edits.
  Future<ProductState> saveProduct(Product product) async {
    await _updateProduct.execute(product);
    return const ProductState().copyWith(product: product);
  }

  /// Loads shared settings (multi-entry dedup fixture).
  Future<Map<String, dynamic>> loadSettings() => _fetchSettings.execute();
}
