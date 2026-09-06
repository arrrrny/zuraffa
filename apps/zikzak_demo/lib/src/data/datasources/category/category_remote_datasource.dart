// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/category/category.dart';
import 'category_datasource.dart';

class CategoryRemoteDataSource
    with Loggable, FailureHandler
    implements CategoryDataSource {
  @override
  Future<Category> get(QueryParams<Category> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Category> update(UpdateParams<String, CategoryPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Category> toggle(
    ToggleParams<String, Field<Category, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
