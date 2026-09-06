// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/chat_session/chat_session.dart';

abstract class ChatSessionDataSource with Loggable, FailureHandler {
  Future<ChatSession> get(QueryParams<ChatSession> params);
  Future<ChatSession> update(UpdateParams<String, ChatSessionPatch> params);
  Future<ChatSession> toggle(
    ToggleParams<String, Field<ChatSession, dynamic>> params,
  );
}

// END GENERATED
