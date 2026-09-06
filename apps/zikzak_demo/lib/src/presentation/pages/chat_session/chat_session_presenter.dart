// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/chat_session/chat_session.dart';
import '../../../domain/usecases/chat_session/get_chat_session_usecase.dart';
import '../../../domain/usecases/chat_session/toggle_chat_session_usecase.dart';
import '../../../domain/usecases/chat_session/update_chat_session_usecase.dart';

class ChatSessionPresenter extends Presenter {
  ChatSessionPresenter() {
    _getChatSession = registerUseCase(getIt<GetChatSessionUseCase>());
    _updateChatSession = registerUseCase(getIt<UpdateChatSessionUseCase>());
    _toggleChatSession = registerUseCase(getIt<ToggleChatSessionUseCase>());
  }

  late final GetChatSessionUseCase _getChatSession;

  late final UpdateChatSessionUseCase _updateChatSession;

  late final ToggleChatSessionUseCase _toggleChatSession;

  Future<Result<ChatSession, AppFailure>> getChatSession(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getChatSession.call(
      QueryParams<ChatSession>(filter: Eq(ChatSessionFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ChatSession, AppFailure>> updateChatSession(
    String id,
    ChatSessionPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateChatSession.call(
      UpdateParams<String, ChatSessionPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ChatSession, AppFailure>> toggleChatSession(
    String id,
    Field<ChatSession, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleChatSession.call(
      ToggleParams<String, Field<ChatSession, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
