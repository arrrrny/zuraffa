// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/category/category_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/category/category_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/category_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_category_repository.dart';
import 'package:zikzak_demo/src/domain/entities/category/category.dart';
import 'package:zikzak_demo/src/domain/repositories/category_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/category/get_category_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingCategoryDataSource
    with Loggable, FailureHandler
    implements CategoryDataSource {
  @override
  Future<Category> get(QueryParams<Category> params) {
    throw (Exception('ThrowingCategoryDataSource.get'));
  }

  @override
  Future<List<Category>> getList(ListQueryParams<Category> params) {
    throw (Exception('ThrowingCategoryDataSource.getList'));
  }

  @override
  Future<Category> create(Category entity) {
    throw (Exception('ThrowingCategoryDataSource.create'));
  }

  @override
  Future<Category> update(UpdateParams<String, CategoryPatch> params) {
    throw (Exception('ThrowingCategoryDataSource.update'));
  }

  @override
  Future<Category> toggle(
    ToggleParams<String, Field<Category, dynamic>> params,
  ) {
    throw (Exception('ThrowingCategoryDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingCategoryDataSource.delete'));
  }

  @override
  Stream<Category> watch(QueryParams<Category> params) {
    throw (Exception('ThrowingCategoryDataSource.watch'));
  }

  @override
  Stream<List<Category>> watchList(ListQueryParams<Category> params) {
    throw (Exception('ThrowingCategoryDataSource.watchList'));
  }
}

void main() {
  late GetCategoryUseCase useCase;
  late GetCategoryUseCase throwingUseCase;
  late DataCategoryRepository repository;
  late DataCategoryRepository throwingRepository;
  late CategoryMockDataSource mockDataSource;
  late ThrowingCategoryDataSource throwingDataSource;
  setUp(() {
    mockDataSource = CategoryMockDataSource();
    throwingDataSource = ThrowingCategoryDataSource();
    repository = DataCategoryRepository(mockDataSource);
    throwingRepository = DataCategoryRepository(throwingDataSource);
    useCase = GetCategoryUseCase(repository);
    throwingUseCase = GetCategoryUseCase(throwingRepository);
  });
  group('GetCategoryUseCase', () {
    final tCategory = CategoryMockData.sampleCategory;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<Category>(filter: Eq(CategoryFields.id, tCategory.id)),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tCategory),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<Category>(filter: Eq(CategoryFields.id, tCategory.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
