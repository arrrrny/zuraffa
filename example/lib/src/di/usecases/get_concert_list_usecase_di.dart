import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/concert_repository.dart';
import '../../domain/usecases/concert/get_concert_list_usecase.dart';

void registerGetConcertListUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetConcertListUseCase>(
    () => GetConcertListUseCase(getIt<ConcertRepository>()),
  );
}
