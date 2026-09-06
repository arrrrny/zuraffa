// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/ai_conversation/ai_conversation_remote_datasource.dart';
import '../../data/repositories/data_ai_conversation_repository.dart';
import '../../domain/repositories/ai_conversation_repository.dart';

void registerAiConversationRepository(GetIt getIt) {
  getIt.registerLazySingleton<AiConversationRepository>(
    () => DataAiConversationRepository(getIt<AiConversationRemoteDataSource>()),
  );
}

// END GENERATED
