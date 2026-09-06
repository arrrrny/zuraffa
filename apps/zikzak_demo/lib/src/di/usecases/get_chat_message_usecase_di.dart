// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/chat_message_repository.dart';
import '../../domain/usecases/chat_message/get_chat_message_usecase.dart';

void registerGetChatMessageUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetChatMessageUseCase>(
    () => GetChatMessageUseCase(getIt<ChatMessageRepository>()),
  );
}

// END GENERATED
