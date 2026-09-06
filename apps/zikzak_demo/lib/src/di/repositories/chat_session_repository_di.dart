// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/chat_session/chat_session_remote_datasource.dart';
import '../../data/repositories/data_chat_session_repository.dart';
import '../../domain/repositories/chat_session_repository.dart';

void registerChatSessionRepository(GetIt getIt) {
  getIt.registerLazySingleton<ChatSessionRepository>(
    () => DataChatSessionRepository(getIt<ChatSessionRemoteDataSource>()),
  );
}

// END GENERATED
