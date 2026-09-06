// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form/dynamic_form_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form/dynamic_form_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/dynamic_form_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_dynamic_form_repository.dart';
import 'package:zikzak_demo/src/domain/entities/dynamic_form/dynamic_form.dart';
import 'package:zikzak_demo/src/domain/repositories/dynamic_form_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/dynamic_form/update_dynamic_form_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingDynamicFormDataSource
    with Loggable, FailureHandler
    implements DynamicFormDataSource {
  @override
  Future<DynamicForm> get(QueryParams<DynamicForm> params) {
    throw (Exception('ThrowingDynamicFormDataSource.get'));
  }

  @override
  Future<List<DynamicForm>> getList(ListQueryParams<DynamicForm> params) {
    throw (Exception('ThrowingDynamicFormDataSource.getList'));
  }

  @override
  Future<DynamicForm> create(DynamicForm entity) {
    throw (Exception('ThrowingDynamicFormDataSource.create'));
  }

  @override
  Future<DynamicForm> update(UpdateParams<String, DynamicFormPatch> params) {
    throw (Exception('ThrowingDynamicFormDataSource.update'));
  }

  @override
  Future<DynamicForm> toggle(
    ToggleParams<String, Field<DynamicForm, dynamic>> params,
  ) {
    throw (Exception('ThrowingDynamicFormDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingDynamicFormDataSource.delete'));
  }

  @override
  Stream<DynamicForm> watch(QueryParams<DynamicForm> params) {
    throw (Exception('ThrowingDynamicFormDataSource.watch'));
  }

  @override
  Stream<List<DynamicForm>> watchList(ListQueryParams<DynamicForm> params) {
    throw (Exception('ThrowingDynamicFormDataSource.watchList'));
  }
}

void main() {
  late UpdateDynamicFormUseCase useCase;
  late UpdateDynamicFormUseCase throwingUseCase;
  late DataDynamicFormRepository repository;
  late DataDynamicFormRepository throwingRepository;
  late DynamicFormMockDataSource mockDataSource;
  late ThrowingDynamicFormDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DynamicFormMockDataSource();
    throwingDataSource = ThrowingDynamicFormDataSource();
    repository = DataDynamicFormRepository(mockDataSource);
    throwingRepository = DataDynamicFormRepository(throwingDataSource);
    useCase = UpdateDynamicFormUseCase(repository);
    throwingUseCase = UpdateDynamicFormUseCase(throwingRepository);
  });
  group('UpdateDynamicFormUseCase', () {
    final tDynamicForm = DynamicFormMockData.sampleDynamicForm;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, DynamicFormPatch>(
          id: tDynamicForm.id,
          data: DynamicFormPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, DynamicFormPatch>(
          id: tDynamicForm.id,
          data: DynamicFormPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
