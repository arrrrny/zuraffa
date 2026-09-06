// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/chat_message/chat_message.dart';
import '../../../domain/usecases/chat_message/get_chat_message_usecase.dart';
import '../../../domain/usecases/chat_message/toggle_chat_message_usecase.dart';
import '../../../domain/usecases/chat_message/update_chat_message_usecase.dart';

class ChatMessagePresenter extends Presenter {
  ChatMessagePresenter() {
    _getChatMessage = registerUseCase(getIt<GetChatMessageUseCase>());
    _updateChatMessage = registerUseCase(getIt<UpdateChatMessageUseCase>());
    _toggleChatMessage = registerUseCase(getIt<ToggleChatMessageUseCase>());
  }

  late final GetChatMessageUseCase _getChatMessage;

  late final UpdateChatMessageUseCase _updateChatMessage;

  late final ToggleChatMessageUseCase _toggleChatMessage;

  Future<Result<ChatMessage, AppFailure>> getChatMessage(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getChatMessage.call(
      QueryParams<ChatMessage>(filter: Eq(ChatMessageFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ChatMessage, AppFailure>> updateChatMessage(
    String id,
    ChatMessagePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateChatMessage.call(
      UpdateParams<String, ChatMessagePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ChatMessage, AppFailure>> toggleChatMessage(
    String id,
    Field<ChatMessage, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleChatMessage.call(
      ToggleParams<String, Field<ChatMessage, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
