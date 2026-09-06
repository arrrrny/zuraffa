// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/deal_repository.dart';
import '../../domain/usecases/deal/get_deal_usecase.dart';

void registerGetDealUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetDealUseCase>(
    () => GetDealUseCase(getIt<DealRepository>()),
  );
}

// END GENERATED
