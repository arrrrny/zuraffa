// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/zik_zak_repository.dart';
import '../../domain/usecases/zik_zak/get_zik_zak_usecase.dart';

void registerGetZikZakUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetZikZakUseCase>(
    () => GetZikZakUseCase(getIt<ZikZakRepository>()),
  );
}

// END GENERATED
