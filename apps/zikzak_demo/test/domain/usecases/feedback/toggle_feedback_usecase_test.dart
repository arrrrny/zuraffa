// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/feedback/feedback_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/feedback/feedback_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/feedback_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_feedback_repository.dart';
import 'package:zikzak_demo/src/domain/entities/feedback/feedback.dart';
import 'package:zikzak_demo/src/domain/repositories/feedback_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/feedback/toggle_feedback_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingFeedbackDataSource
    with Loggable, FailureHandler
    implements FeedbackDataSource {
  @override
  Future<Feedback> get(QueryParams<Feedback> params) {
    throw (Exception('ThrowingFeedbackDataSource.get'));
  }

  @override
  Future<List<Feedback>> getList(ListQueryParams<Feedback> params) {
    throw (Exception('ThrowingFeedbackDataSource.getList'));
  }

  @override
  Future<Feedback> create(Feedback entity) {
    throw (Exception('ThrowingFeedbackDataSource.create'));
  }

  @override
  Future<Feedback> update(UpdateParams<String, FeedbackPatch> params) {
    throw (Exception('ThrowingFeedbackDataSource.update'));
  }

  @override
  Future<Feedback> toggle(
    ToggleParams<String, Field<Feedback, dynamic>> params,
  ) {
    throw (Exception('ThrowingFeedbackDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingFeedbackDataSource.delete'));
  }

  @override
  Stream<Feedback> watch(QueryParams<Feedback> params) {
    throw (Exception('ThrowingFeedbackDataSource.watch'));
  }

  @override
  Stream<List<Feedback>> watchList(ListQueryParams<Feedback> params) {
    throw (Exception('ThrowingFeedbackDataSource.watchList'));
  }
}

void main() {
  late ToggleFeedbackUseCase useCase;
  late ToggleFeedbackUseCase throwingUseCase;
  late DataFeedbackRepository repository;
  late DataFeedbackRepository throwingRepository;
  late FeedbackMockDataSource mockDataSource;
  late ThrowingFeedbackDataSource throwingDataSource;
  setUp(() {
    mockDataSource = FeedbackMockDataSource();
    throwingDataSource = ThrowingFeedbackDataSource();
    repository = DataFeedbackRepository(mockDataSource);
    throwingRepository = DataFeedbackRepository(throwingDataSource);
    useCase = ToggleFeedbackUseCase(repository);
    throwingUseCase = ToggleFeedbackUseCase(throwingRepository);
  });
  group('ToggleFeedbackUseCase', () {
    final tFeedback = FeedbackMockData.sampleFeedback;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Feedback, dynamic>>(
          id: tFeedback.id,
          field: FeedbackFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Feedback, dynamic>>(
          id: tFeedback.id,
          field: FeedbackFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
