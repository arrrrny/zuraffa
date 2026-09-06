// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/chat_message/chat_message_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/chat_message/chat_message_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/chat_message_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_chat_message_repository.dart';
import 'package:zikzak_demo/src/domain/entities/chat_message/chat_message.dart';
import 'package:zikzak_demo/src/domain/repositories/chat_message_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/chat_message/toggle_chat_message_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingChatMessageDataSource
    with Loggable, FailureHandler
    implements ChatMessageDataSource {
  @override
  Future<ChatMessage> get(QueryParams<ChatMessage> params) {
    throw (Exception('ThrowingChatMessageDataSource.get'));
  }

  @override
  Future<List<ChatMessage>> getList(ListQueryParams<ChatMessage> params) {
    throw (Exception('ThrowingChatMessageDataSource.getList'));
  }

  @override
  Future<ChatMessage> create(ChatMessage entity) {
    throw (Exception('ThrowingChatMessageDataSource.create'));
  }

  @override
  Future<ChatMessage> update(UpdateParams<String, ChatMessagePatch> params) {
    throw (Exception('ThrowingChatMessageDataSource.update'));
  }

  @override
  Future<ChatMessage> toggle(
    ToggleParams<String, Field<ChatMessage, dynamic>> params,
  ) {
    throw (Exception('ThrowingChatMessageDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingChatMessageDataSource.delete'));
  }

  @override
  Stream<ChatMessage> watch(QueryParams<ChatMessage> params) {
    throw (Exception('ThrowingChatMessageDataSource.watch'));
  }

  @override
  Stream<List<ChatMessage>> watchList(ListQueryParams<ChatMessage> params) {
    throw (Exception('ThrowingChatMessageDataSource.watchList'));
  }
}

void main() {
  late ToggleChatMessageUseCase useCase;
  late ToggleChatMessageUseCase throwingUseCase;
  late DataChatMessageRepository repository;
  late DataChatMessageRepository throwingRepository;
  late ChatMessageMockDataSource mockDataSource;
  late ThrowingChatMessageDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ChatMessageMockDataSource();
    throwingDataSource = ThrowingChatMessageDataSource();
    repository = DataChatMessageRepository(mockDataSource);
    throwingRepository = DataChatMessageRepository(throwingDataSource);
    useCase = ToggleChatMessageUseCase(repository);
    throwingUseCase = ToggleChatMessageUseCase(throwingRepository);
  });
  group('ToggleChatMessageUseCase', () {
    final tChatMessage = ChatMessageMockData.sampleChatMessage;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<ChatMessage, dynamic>>(
          id: tChatMessage.id,
          field: ChatMessageFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<ChatMessage, dynamic>>(
          id: tChatMessage.id,
          field: ChatMessageFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
