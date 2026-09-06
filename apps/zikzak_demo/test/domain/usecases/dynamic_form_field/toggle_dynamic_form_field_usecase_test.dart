// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form_field/dynamic_form_field_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/dynamic_form_field/dynamic_form_field_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/dynamic_form_field_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_dynamic_form_field_repository.dart';
import 'package:zikzak_demo/src/domain/entities/dynamic_form_field/dynamic_form_field.dart';
import 'package:zikzak_demo/src/domain/repositories/dynamic_form_field_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/dynamic_form_field/toggle_dynamic_form_field_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingDynamicFormFieldDataSource
    with Loggable, FailureHandler
    implements DynamicFormFieldDataSource {
  @override
  Future<DynamicFormField> get(QueryParams<DynamicFormField> params) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.get'));
  }

  @override
  Future<List<DynamicFormField>> getList(
    ListQueryParams<DynamicFormField> params,
  ) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.getList'));
  }

  @override
  Future<DynamicFormField> create(DynamicFormField entity) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.create'));
  }

  @override
  Future<DynamicFormField> update(
    UpdateParams<String, DynamicFormFieldPatch> params,
  ) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.update'));
  }

  @override
  Future<DynamicFormField> toggle(
    ToggleParams<String, Field<DynamicFormField, dynamic>> params,
  ) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.delete'));
  }

  @override
  Stream<DynamicFormField> watch(QueryParams<DynamicFormField> params) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.watch'));
  }

  @override
  Stream<List<DynamicFormField>> watchList(
    ListQueryParams<DynamicFormField> params,
  ) {
    throw (Exception('ThrowingDynamicFormFieldDataSource.watchList'));
  }
}

void main() {
  late ToggleDynamicFormFieldUseCase useCase;
  late ToggleDynamicFormFieldUseCase throwingUseCase;
  late DataDynamicFormFieldRepository repository;
  late DataDynamicFormFieldRepository throwingRepository;
  late DynamicFormFieldMockDataSource mockDataSource;
  late ThrowingDynamicFormFieldDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DynamicFormFieldMockDataSource();
    throwingDataSource = ThrowingDynamicFormFieldDataSource();
    repository = DataDynamicFormFieldRepository(mockDataSource);
    throwingRepository = DataDynamicFormFieldRepository(throwingDataSource);
    useCase = ToggleDynamicFormFieldUseCase(repository);
    throwingUseCase = ToggleDynamicFormFieldUseCase(throwingRepository);
  });
  group('ToggleDynamicFormFieldUseCase', () {
    final tDynamicFormField = DynamicFormFieldMockData.sampleDynamicFormField;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<DynamicFormField, dynamic>>(
          id: tDynamicFormField.id,
          field: DynamicFormFieldFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<DynamicFormField, dynamic>>(
          id: tDynamicFormField.id,
          field: DynamicFormFieldFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
