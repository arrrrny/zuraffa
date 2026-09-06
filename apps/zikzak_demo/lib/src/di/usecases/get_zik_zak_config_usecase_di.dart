// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_config_repository.dart';
import '../../domain/usecases/zik_zak_config/get_zik_zak_config_usecase.dart';

void registerGetZikZakConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetZikZakConfigUseCase>(
    () => GetZikZakConfigUseCase(getIt<ZikZakConfigRepository>()),
  );
}

// END GENERATED
