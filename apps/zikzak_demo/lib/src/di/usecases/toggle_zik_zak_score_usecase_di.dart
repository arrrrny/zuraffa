// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_score_repository.dart';
import '../../domain/usecases/zik_zak_score/toggle_zik_zak_score_usecase.dart';

void registerToggleZikZakScoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleZikZakScoreUseCase>(
    () => ToggleZikZakScoreUseCase(getIt<ZikZakScoreRepository>()),
  );
}

// END GENERATED
