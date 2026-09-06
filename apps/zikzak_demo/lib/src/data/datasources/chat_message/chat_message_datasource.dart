// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/chat_message/chat_message.dart';

abstract class ChatMessageDataSource with Loggable, FailureHandler {
  Future<ChatMessage> get(QueryParams<ChatMessage> params);
  Future<ChatMessage> update(UpdateParams<String, ChatMessagePatch> params);
  Future<ChatMessage> toggle(
    ToggleParams<String, Field<ChatMessage, dynamic>> params,
  );
}

// END GENERATED
