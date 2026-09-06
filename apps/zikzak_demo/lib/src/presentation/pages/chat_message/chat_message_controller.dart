// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/chat_message/chat_message.dart';
import 'chat_message_presenter.dart';

class ChatMessageController extends Controller {
  ChatMessageController(this._presenter);

  final ChatMessagePresenter _presenter;

  Future<void> getChatMessage(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getChatMessage(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateChatMessage(
    String id,
    ChatMessagePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateChatMessage(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleChatMessage(
    String id,
    Field<ChatMessage, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleChatMessage(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
