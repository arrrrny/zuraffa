// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/form_option/form_option_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/form_option/form_option_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/form_option_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_form_option_repository.dart';
import 'package:zikzak_demo/src/domain/entities/form_option/form_option.dart';
import 'package:zikzak_demo/src/domain/repositories/form_option_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/form_option/toggle_form_option_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingFormOptionDataSource
    with Loggable, FailureHandler
    implements FormOptionDataSource {
  @override
  Future<FormOption> get(QueryParams<FormOption> params) {
    throw (Exception('ThrowingFormOptionDataSource.get'));
  }

  @override
  Future<List<FormOption>> getList(ListQueryParams<FormOption> params) {
    throw (Exception('ThrowingFormOptionDataSource.getList'));
  }

  @override
  Future<FormOption> create(FormOption entity) {
    throw (Exception('ThrowingFormOptionDataSource.create'));
  }

  @override
  Future<FormOption> update(UpdateParams<String, FormOptionPatch> params) {
    throw (Exception('ThrowingFormOptionDataSource.update'));
  }

  @override
  Future<FormOption> toggle(
    ToggleParams<String, Field<FormOption, dynamic>> params,
  ) {
    throw (Exception('ThrowingFormOptionDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingFormOptionDataSource.delete'));
  }

  @override
  Stream<FormOption> watch(QueryParams<FormOption> params) {
    throw (Exception('ThrowingFormOptionDataSource.watch'));
  }

  @override
  Stream<List<FormOption>> watchList(ListQueryParams<FormOption> params) {
    throw (Exception('ThrowingFormOptionDataSource.watchList'));
  }
}

void main() {
  late ToggleFormOptionUseCase useCase;
  late ToggleFormOptionUseCase throwingUseCase;
  late DataFormOptionRepository repository;
  late DataFormOptionRepository throwingRepository;
  late FormOptionMockDataSource mockDataSource;
  late ThrowingFormOptionDataSource throwingDataSource;
  setUp(() {
    mockDataSource = FormOptionMockDataSource();
    throwingDataSource = ThrowingFormOptionDataSource();
    repository = DataFormOptionRepository(mockDataSource);
    throwingRepository = DataFormOptionRepository(throwingDataSource);
    useCase = ToggleFormOptionUseCase(repository);
    throwingUseCase = ToggleFormOptionUseCase(throwingRepository);
  });
  group('ToggleFormOptionUseCase', () {
    final tFormOption = FormOptionMockData.sampleFormOption;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<FormOption, dynamic>>(
          id: tFormOption.id,
          field: FormOptionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<FormOption, dynamic>>(
          id: tFormOption.id,
          field: FormOptionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
