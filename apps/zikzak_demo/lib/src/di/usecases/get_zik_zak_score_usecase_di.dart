// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_score_repository.dart';
import '../../domain/usecases/zik_zak_score/get_zik_zak_score_usecase.dart';

void registerGetZikZakScoreUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetZikZakScoreUseCase>(
    () => GetZikZakScoreUseCase(getIt<ZikZakScoreRepository>()),
  );
}

// END GENERATED
