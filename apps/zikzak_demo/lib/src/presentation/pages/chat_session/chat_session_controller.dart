// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/chat_session/chat_session.dart';
import 'chat_session_presenter.dart';

class ChatSessionController extends Controller {
  ChatSessionController(this._presenter);

  final ChatSessionPresenter _presenter;

  Future<void> getChatSession(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getChatSession(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateChatSession(
    String id,
    ChatSessionPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateChatSession(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleChatSession(
    String id,
    Field<ChatSession, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleChatSession(
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
