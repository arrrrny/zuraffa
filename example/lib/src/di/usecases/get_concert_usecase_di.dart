import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/concert_repository.dart';
import '../../domain/usecases/concert/get_concert_usecase.dart';

void registerGetConcertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetConcertUseCase>(
    () => GetConcertUseCase(getIt<ConcertRepository>()),
  );
}
