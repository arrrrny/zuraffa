// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_session_repository.dart';
import '../../domain/usecases/chat_session/toggle_chat_session_usecase.dart';

void registerToggleChatSessionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleChatSessionUseCase>(
    () => ToggleChatSessionUseCase(getIt<ChatSessionRepository>()),
  );
}

// END GENERATED
