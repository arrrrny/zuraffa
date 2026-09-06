// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/feedback_repository.dart';
import '../../domain/usecases/feedback/get_feedback_usecase.dart';

void registerGetFeedbackUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetFeedbackUseCase>(
    () => GetFeedbackUseCase(getIt<FeedbackRepository>()),
  );
}

// END GENERATED
