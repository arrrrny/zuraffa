// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/ai_conversation_repository.dart';
import '../../domain/usecases/ai_conversation/get_ai_conversation_usecase.dart';

void registerGetAiConversationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetAiConversationUseCase>(
    () => GetAiConversationUseCase(getIt<AiConversationRepository>()),
  );
}

// END GENERATED
