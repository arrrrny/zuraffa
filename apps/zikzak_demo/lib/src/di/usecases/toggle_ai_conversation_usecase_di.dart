// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/ai_conversation_repository.dart';
import '../../domain/usecases/ai_conversation/toggle_ai_conversation_usecase.dart';

void registerToggleAiConversationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleAiConversationUseCase>(
    () => ToggleAiConversationUseCase(getIt<AiConversationRepository>()),
  );
}

// END GENERATED
