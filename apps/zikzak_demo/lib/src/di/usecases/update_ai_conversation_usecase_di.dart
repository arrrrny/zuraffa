// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/ai_conversation_repository.dart';
import '../../domain/usecases/ai_conversation/update_ai_conversation_usecase.dart';

void registerUpdateAiConversationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateAiConversationUseCase>(
    () => UpdateAiConversationUseCase(getIt<AiConversationRepository>()),
  );
}

// END GENERATED
