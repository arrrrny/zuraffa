// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_message_repository.dart';
import '../../domain/usecases/chat_message/toggle_chat_message_usecase.dart';

void registerToggleChatMessageUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleChatMessageUseCase>(
    () => ToggleChatMessageUseCase(getIt<ChatMessageRepository>()),
  );
}

// END GENERATED
