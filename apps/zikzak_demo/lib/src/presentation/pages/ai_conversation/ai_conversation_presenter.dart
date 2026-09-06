// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/ai_conversation/ai_conversation.dart';
import '../../../domain/usecases/ai_conversation/get_ai_conversation_usecase.dart';
import '../../../domain/usecases/ai_conversation/toggle_ai_conversation_usecase.dart';
import '../../../domain/usecases/ai_conversation/update_ai_conversation_usecase.dart';

class AiConversationPresenter extends Presenter {
  AiConversationPresenter() {
    _getAiConversation = registerUseCase(getIt<GetAiConversationUseCase>());
    _updateAiConversation = registerUseCase(
      getIt<UpdateAiConversationUseCase>(),
    );
    _toggleAiConversation = registerUseCase(
      getIt<ToggleAiConversationUseCase>(),
    );
  }

  late final GetAiConversationUseCase _getAiConversation;

  late final UpdateAiConversationUseCase _updateAiConversation;

  late final ToggleAiConversationUseCase _toggleAiConversation;

  Future<Result<AiConversation, AppFailure>> getAiConversation(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getAiConversation.call(
      QueryParams<AiConversation>(filter: Eq(AiConversationFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AiConversation, AppFailure>> updateAiConversation(
    String id,
    AiConversationPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateAiConversation.call(
      UpdateParams<String, AiConversationPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AiConversation, AppFailure>> toggleAiConversation(
    String id,
    Field<AiConversation, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleAiConversation.call(
      ToggleParams<String, Field<AiConversation, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
