// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_config_repository.dart';
import '../../domain/usecases/zik_zak_config/toggle_zik_zak_config_usecase.dart';

void registerToggleZikZakConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleZikZakConfigUseCase>(
    () => ToggleZikZakConfigUseCase(getIt<ZikZakConfigRepository>()),
  );
}

// END GENERATED
