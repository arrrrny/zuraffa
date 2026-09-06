// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/form_option/form_option_remote_datasource.dart';
import '../../data/repositories/data_form_option_repository.dart';
import '../../domain/repositories/form_option_repository.dart';

void registerFormOptionRepository(GetIt getIt) {
  getIt.registerLazySingleton<FormOptionRepository>(
    () => DataFormOptionRepository(getIt<FormOptionRemoteDataSource>()),
  );
}

// END GENERATED
