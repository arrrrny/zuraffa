// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/chat_session/chat_session.dart';
import 'chat_session_datasource.dart';

class ChatSessionRemoteDataSource
    with Loggable, FailureHandler
    implements ChatSessionDataSource {
  @override
  Future<ChatSession> get(QueryParams<ChatSession> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ChatSession> update(
    UpdateParams<String, ChatSessionPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ChatSession> toggle(
    ToggleParams<String, Field<ChatSession, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
