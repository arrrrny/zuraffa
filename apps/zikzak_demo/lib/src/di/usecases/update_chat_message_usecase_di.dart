// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_message_repository.dart';
import '../../domain/usecases/chat_message/update_chat_message_usecase.dart';

void registerUpdateChatMessageUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateChatMessageUseCase>(
    () => UpdateChatMessageUseCase(getIt<ChatMessageRepository>()),
  );
}

// END GENERATED
