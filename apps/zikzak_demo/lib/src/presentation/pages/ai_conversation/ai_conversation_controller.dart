// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/ai_conversation/ai_conversation.dart';
import 'ai_conversation_presenter.dart';

class AiConversationController extends Controller {
  AiConversationController(this._presenter);

  final AiConversationPresenter _presenter;

  Future<void> getAiConversation(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getAiConversation(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateAiConversation(
    String id,
    AiConversationPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateAiConversation(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleAiConversation(
    String id,
    Field<AiConversation, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleAiConversation(
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
