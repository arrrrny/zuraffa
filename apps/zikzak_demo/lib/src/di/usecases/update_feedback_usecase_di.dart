// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/feedback_repository.dart';
import '../../domain/usecases/feedback/update_feedback_usecase.dart';

void registerUpdateFeedbackUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateFeedbackUseCase>(
    () => UpdateFeedbackUseCase(getIt<FeedbackRepository>()),
  );
}

// END GENERATED
