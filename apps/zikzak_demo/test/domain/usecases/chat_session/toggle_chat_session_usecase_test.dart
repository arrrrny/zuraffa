// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/chat_session/chat_session_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/chat_session/chat_session_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/chat_session_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_chat_session_repository.dart';
import 'package:zikzak_demo/src/domain/entities/chat_session/chat_session.dart';
import 'package:zikzak_demo/src/domain/repositories/chat_session_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/chat_session/toggle_chat_session_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingChatSessionDataSource
    with Loggable, FailureHandler
    implements ChatSessionDataSource {
  @override
  Future<ChatSession> get(QueryParams<ChatSession> params) {
    throw (Exception('ThrowingChatSessionDataSource.get'));
  }

  @override
  Future<List<ChatSession>> getList(ListQueryParams<ChatSession> params) {
    throw (Exception('ThrowingChatSessionDataSource.getList'));
  }

  @override
  Future<ChatSession> create(ChatSession entity) {
    throw (Exception('ThrowingChatSessionDataSource.create'));
  }

  @override
  Future<ChatSession> update(UpdateParams<String, ChatSessionPatch> params) {
    throw (Exception('ThrowingChatSessionDataSource.update'));
  }

  @override
  Future<ChatSession> toggle(
    ToggleParams<String, Field<ChatSession, dynamic>> params,
  ) {
    throw (Exception('ThrowingChatSessionDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingChatSessionDataSource.delete'));
  }

  @override
  Stream<ChatSession> watch(QueryParams<ChatSession> params) {
    throw (Exception('ThrowingChatSessionDataSource.watch'));
  }

  @override
  Stream<List<ChatSession>> watchList(ListQueryParams<ChatSession> params) {
    throw (Exception('ThrowingChatSessionDataSource.watchList'));
  }
}

void main() {
  late ToggleChatSessionUseCase useCase;
  late ToggleChatSessionUseCase throwingUseCase;
  late DataChatSessionRepository repository;
  late DataChatSessionRepository throwingRepository;
  late ChatSessionMockDataSource mockDataSource;
  late ThrowingChatSessionDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ChatSessionMockDataSource();
    throwingDataSource = ThrowingChatSessionDataSource();
    repository = DataChatSessionRepository(mockDataSource);
    throwingRepository = DataChatSessionRepository(throwingDataSource);
    useCase = ToggleChatSessionUseCase(repository);
    throwingUseCase = ToggleChatSessionUseCase(throwingRepository);
  });
  group('ToggleChatSessionUseCase', () {
    final tChatSession = ChatSessionMockData.sampleChatSession;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<ChatSession, dynamic>>(
          id: tChatSession.id,
          field: ChatSessionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<ChatSession, dynamic>>(
          id: tChatSession.id,
          field: ChatSessionFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
