// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/form_submission/form_submission_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/form_submission/form_submission_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/form_submission_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_form_submission_repository.dart';
import 'package:zikzak_demo/src/domain/entities/form_submission/form_submission.dart';
import 'package:zikzak_demo/src/domain/repositories/form_submission_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/form_submission/update_form_submission_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingFormSubmissionDataSource
    with Loggable, FailureHandler
    implements FormSubmissionDataSource {
  @override
  Future<FormSubmission> get(QueryParams<FormSubmission> params) {
    throw (Exception('ThrowingFormSubmissionDataSource.get'));
  }

  @override
  Future<List<FormSubmission>> getList(ListQueryParams<FormSubmission> params) {
    throw (Exception('ThrowingFormSubmissionDataSource.getList'));
  }

  @override
  Future<FormSubmission> create(FormSubmission entity) {
    throw (Exception('ThrowingFormSubmissionDataSource.create'));
  }

  @override
  Future<FormSubmission> update(
    UpdateParams<String, FormSubmissionPatch> params,
  ) {
    throw (Exception('ThrowingFormSubmissionDataSource.update'));
  }

  @override
  Future<FormSubmission> toggle(
    ToggleParams<String, Field<FormSubmission, dynamic>> params,
  ) {
    throw (Exception('ThrowingFormSubmissionDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingFormSubmissionDataSource.delete'));
  }

  @override
  Stream<FormSubmission> watch(QueryParams<FormSubmission> params) {
    throw (Exception('ThrowingFormSubmissionDataSource.watch'));
  }

  @override
  Stream<List<FormSubmission>> watchList(
    ListQueryParams<FormSubmission> params,
  ) {
    throw (Exception('ThrowingFormSubmissionDataSource.watchList'));
  }
}

void main() {
  late UpdateFormSubmissionUseCase useCase;
  late UpdateFormSubmissionUseCase throwingUseCase;
  late DataFormSubmissionRepository repository;
  late DataFormSubmissionRepository throwingRepository;
  late FormSubmissionMockDataSource mockDataSource;
  late ThrowingFormSubmissionDataSource throwingDataSource;
  setUp(() {
    mockDataSource = FormSubmissionMockDataSource();
    throwingDataSource = ThrowingFormSubmissionDataSource();
    repository = DataFormSubmissionRepository(mockDataSource);
    throwingRepository = DataFormSubmissionRepository(throwingDataSource);
    useCase = UpdateFormSubmissionUseCase(repository);
    throwingUseCase = UpdateFormSubmissionUseCase(throwingRepository);
  });
  group('UpdateFormSubmissionUseCase', () {
    final tFormSubmission = FormSubmissionMockData.sampleFormSubmission;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, FormSubmissionPatch>(
          id: tFormSubmission.id,
          data: FormSubmissionPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, FormSubmissionPatch>(
          id: tFormSubmission.id,
          data: FormSubmissionPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
