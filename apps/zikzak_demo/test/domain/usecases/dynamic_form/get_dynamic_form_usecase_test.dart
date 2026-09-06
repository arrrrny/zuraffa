// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form/dynamic_form_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form/dynamic_form_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/dynamic_form_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_dynamic_form_repository.dart';
import 'package:zikzak_demo/src/domain/entities/dynamic_form/dynamic_form.dart';
import 'package:zikzak_demo/src/domain/repositories/dynamic_form_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/dynamic_form/get_dynamic_form_usecase.dart';
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
  late GetDynamicFormUseCase useCase;
  late GetDynamicFormUseCase throwingUseCase;
  late DataDynamicFormRepository repository;
  late DataDynamicFormRepository throwingRepository;
  late DynamicFormMockDataSource mockDataSource;
  late ThrowingDynamicFormDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DynamicFormMockDataSource();
    throwingDataSource = ThrowingDynamicFormDataSource();
    repository = DataDynamicFormRepository(mockDataSource);
    throwingRepository = DataDynamicFormRepository(throwingDataSource);
    useCase = GetDynamicFormUseCase(repository);
    throwingUseCase = GetDynamicFormUseCase(throwingRepository);
  });
  group('GetDynamicFormUseCase', () {
    final tDynamicForm = DynamicFormMockData.sampleDynamicForm;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<DynamicForm>(
          filter: Eq(DynamicFormFields.id, tDynamicForm.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tDynamicForm),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<DynamicForm>(
          filter: Eq(DynamicFormFields.id, tDynamicForm.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
