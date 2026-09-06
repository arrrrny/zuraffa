// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/category/category.dart';
import '../../../domain/usecases/category/get_category_usecase.dart';
import '../../../domain/usecases/category/toggle_category_usecase.dart';
import '../../../domain/usecases/category/update_category_usecase.dart';

class CategoryPresenter extends Presenter {
  CategoryPresenter() {
    _getCategory = registerUseCase(getIt<GetCategoryUseCase>());
    _updateCategory = registerUseCase(getIt<UpdateCategoryUseCase>());
    _toggleCategory = registerUseCase(getIt<ToggleCategoryUseCase>());
  }

  late final GetCategoryUseCase _getCategory;

  late final UpdateCategoryUseCase _updateCategory;

  late final ToggleCategoryUseCase _toggleCategory;

  Future<Result<Category, AppFailure>> getCategory(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getCategory.call(
      QueryParams<Category>(filter: Eq(CategoryFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Category, AppFailure>> updateCategory(
    String id,
    CategoryPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateCategory.call(
      UpdateParams<String, CategoryPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Category, AppFailure>> toggleCategory(
    String id,
    Field<Category, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleCategory.call(
      ToggleParams<String, Field<Category, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
