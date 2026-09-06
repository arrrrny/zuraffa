// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/feedback_repository.dart';
import '../../domain/usecases/feedback/toggle_feedback_usecase.dart';

void registerToggleFeedbackUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleFeedbackUseCase>(
    () => ToggleFeedbackUseCase(getIt<FeedbackRepository>()),
  );
}

// END GENERATED
