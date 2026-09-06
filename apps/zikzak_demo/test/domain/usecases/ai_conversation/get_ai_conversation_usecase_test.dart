// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/ai_conversation/ai_conversation_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/ai_conversation/ai_conversation_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/ai_conversation_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_ai_conversation_repository.dart';
import 'package:zikzak_demo/src/domain/entities/ai_conversation/ai_conversation.dart';
import 'package:zikzak_demo/src/domain/repositories/ai_conversation_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/ai_conversation/get_ai_conversation_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingAiConversationDataSource
    with Loggable, FailureHandler
    implements AiConversationDataSource {
  @override
  Future<AiConversation> get(QueryParams<AiConversation> params) {
    throw (Exception('ThrowingAiConversationDataSource.get'));
  }

  @override
  Future<List<AiConversation>> getList(ListQueryParams<AiConversation> params) {
    throw (Exception('ThrowingAiConversationDataSource.getList'));
  }

  @override
  Future<AiConversation> create(AiConversation entity) {
    throw (Exception('ThrowingAiConversationDataSource.create'));
  }

  @override
  Future<AiConversation> update(
    UpdateParams<String, AiConversationPatch> params,
  ) {
    throw (Exception('ThrowingAiConversationDataSource.update'));
  }

  @override
  Future<AiConversation> toggle(
    ToggleParams<String, Field<AiConversation, dynamic>> params,
  ) {
    throw (Exception('ThrowingAiConversationDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingAiConversationDataSource.delete'));
  }

  @override
  Stream<AiConversation> watch(QueryParams<AiConversation> params) {
    throw (Exception('ThrowingAiConversationDataSource.watch'));
  }

  @override
  Stream<List<AiConversation>> watchList(
    ListQueryParams<AiConversation> params,
  ) {
    throw (Exception('ThrowingAiConversationDataSource.watchList'));
  }
}

void main() {
  late GetAiConversationUseCase useCase;
  late GetAiConversationUseCase throwingUseCase;
  late DataAiConversationRepository repository;
  late DataAiConversationRepository throwingRepository;
  late AiConversationMockDataSource mockDataSource;
  late ThrowingAiConversationDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AiConversationMockDataSource();
    throwingDataSource = ThrowingAiConversationDataSource();
    repository = DataAiConversationRepository(mockDataSource);
    throwingRepository = DataAiConversationRepository(throwingDataSource);
    useCase = GetAiConversationUseCase(repository);
    throwingUseCase = GetAiConversationUseCase(throwingRepository);
  });
  group('GetAiConversationUseCase', () {
    final tAiConversation = AiConversationMockData.sampleAiConversation;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<AiConversation>(
          filter: Eq(AiConversationFields.id, tAiConversation.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tAiConversation),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<AiConversation>(
          filter: Eq(AiConversationFields.id, tAiConversation.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
