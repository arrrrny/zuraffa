// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_repository.dart';
import '../../domain/usecases/zik_zak/toggle_zik_zak_usecase.dart';

void registerToggleZikZakUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleZikZakUseCase>(
    () => ToggleZikZakUseCase(getIt<ZikZakRepository>()),
  );
}

// END GENERATED
