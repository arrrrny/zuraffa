// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_repository.dart';
import '../../domain/usecases/zik_zak/update_zik_zak_usecase.dart';

void registerUpdateZikZakUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateZikZakUseCase>(
    () => UpdateZikZakUseCase(getIt<ZikZakRepository>()),
  );
}

// END GENERATED
