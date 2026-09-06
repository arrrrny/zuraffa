// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/deal_repository.dart';
import '../../domain/usecases/deal/toggle_deal_usecase.dart';

void registerToggleDealUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleDealUseCase>(
    () => ToggleDealUseCase(getIt<DealRepository>()),
  );
}

// END GENERATED
