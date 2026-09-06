// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/ai_conversation/ai_conversation.dart';

abstract class AiConversationDataSource with Loggable, FailureHandler {
  Future<AiConversation> get(QueryParams<AiConversation> params);
  Future<AiConversation> update(
    UpdateParams<String, AiConversationPatch> params,
  );
  Future<AiConversation> toggle(
    ToggleParams<String, Field<AiConversation, dynamic>> params,
  );
}

// END GENERATED
