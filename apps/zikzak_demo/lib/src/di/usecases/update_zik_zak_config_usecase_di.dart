// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_config_repository.dart';
import '../../domain/usecases/zik_zak_config/update_zik_zak_config_usecase.dart';

void registerUpdateZikZakConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateZikZakConfigUseCase>(
    () => UpdateZikZakConfigUseCase(getIt<ZikZakConfigRepository>()),
  );
}

// END GENERATED
