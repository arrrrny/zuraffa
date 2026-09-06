// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/chat_message/chat_message.dart';
import 'chat_message_datasource.dart';

class ChatMessageRemoteDataSource
    with Loggable, FailureHandler
    implements ChatMessageDataSource {
  @override
  Future<ChatMessage> get(QueryParams<ChatMessage> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ChatMessage> update(
    UpdateParams<String, ChatMessagePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ChatMessage> toggle(
    ToggleParams<String, Field<ChatMessage, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
