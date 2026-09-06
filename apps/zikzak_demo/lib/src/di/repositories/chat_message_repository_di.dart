// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/chat_message/chat_message_remote_datasource.dart';
import '../../data/repositories/data_chat_message_repository.dart';
import '../../domain/repositories/chat_message_repository.dart';

void registerChatMessageRepository(GetIt getIt) {
  getIt.registerLazySingleton<ChatMessageRepository>(
    () => DataChatMessageRepository(getIt<ChatMessageRemoteDataSource>()),
  );
}

// END GENERATED
