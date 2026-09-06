// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_session_repository.dart';
import '../../domain/usecases/chat_session/get_chat_session_usecase.dart';

void registerGetChatSessionUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetChatSessionUseCase>(
    () => GetChatSessionUseCase(getIt<ChatSessionRepository>()),
  );
}

// END GENERATED
