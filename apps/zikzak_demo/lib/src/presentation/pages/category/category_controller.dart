// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/category/category.dart';
import 'category_presenter.dart';

class CategoryController extends Controller {
  CategoryController(this._presenter);

  final CategoryPresenter _presenter;

  Future<void> getCategory(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getCategory(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateCategory(
    String id,
    CategoryPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateCategory(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleCategory(
    String id,
    Field<Category, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleCategory(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
