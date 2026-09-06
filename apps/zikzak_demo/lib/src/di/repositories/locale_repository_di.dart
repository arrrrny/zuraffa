// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/locale/locale_remote_datasource.dart';
import '../../data/repositories/data_locale_repository.dart';
import '../../domain/repositories/locale_repository.dart';

void registerLocaleRepository(GetIt getIt) {
  getIt.registerLazySingleton<LocaleRepository>(
    () => DataLocaleRepository(getIt<LocaleRemoteDataSource>()),
  );
}

// END GENERATED
