import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/concert_repository.dart';
import '../../domain/usecases/concert/watch_concert_usecase.dart';

void registerWatchConcertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<WatchConcertUseCase>(
    () => WatchConcertUseCase(getIt<ConcertRepository>()),
  );
}
