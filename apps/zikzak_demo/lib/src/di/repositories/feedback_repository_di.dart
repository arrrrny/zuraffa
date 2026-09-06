// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/feedback/feedback_remote_datasource.dart';
import '../../data/repositories/data_feedback_repository.dart';
import '../../domain/repositories/feedback_repository.dart';

void registerFeedbackRepository(GetIt getIt) {
  getIt.registerLazySingleton<FeedbackRepository>(
    () => DataFeedbackRepository(getIt<FeedbackRemoteDataSource>()),
  );
}

// END GENERATED
