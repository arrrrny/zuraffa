// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/ai_conversation/ai_conversation.dart';
import 'ai_conversation_datasource.dart';

class AiConversationRemoteDataSource
    with Loggable, FailureHandler
    implements AiConversationDataSource {
  @override
  Future<AiConversation> get(QueryParams<AiConversation> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<AiConversation> update(
    UpdateParams<String, AiConversationPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<AiConversation> toggle(
    ToggleParams<String, Field<AiConversation, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
