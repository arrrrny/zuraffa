import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/concert_repository.dart';
import '../../domain/usecases/concert/update_concert_usecase.dart';

void registerUpdateConcertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateConcertUseCase>(
    () => UpdateConcertUseCase(getIt<ConcertRepository>()),
  );
}
