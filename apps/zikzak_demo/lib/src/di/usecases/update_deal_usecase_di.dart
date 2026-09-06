// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/deal_repository.dart';
import '../../domain/usecases/deal/update_deal_usecase.dart';

void registerUpdateDealUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateDealUseCase>(
    () => UpdateDealUseCase(getIt<DealRepository>()),
  );
}

// END GENERATED
