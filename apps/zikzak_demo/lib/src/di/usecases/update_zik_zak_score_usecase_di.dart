// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_score_repository.dart';
import '../../domain/usecases/zik_zak_score/update_zik_zak_score_usecase.dart';

void registerUpdateZikZakScoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateZikZakScoreUseCase>(
    () => UpdateZikZakScoreUseCase(getIt<ZikZakScoreRepository>()),
  );
}

// END GENERATED
