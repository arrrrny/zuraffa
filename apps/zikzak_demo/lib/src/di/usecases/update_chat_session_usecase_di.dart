// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_session_repository.dart';
import '../../domain/usecases/chat_session/update_chat_session_usecase.dart';

void registerUpdateChatSessionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateChatSessionUseCase>(
    () => UpdateChatSessionUseCase(getIt<ChatSessionRepository>()),
  );
}

// END GENERATED
