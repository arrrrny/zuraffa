// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/dynamic_form/dynamic_form_remote_datasource.dart';
import '../../data/repositories/data_dynamic_form_repository.dart';
import '../../domain/repositories/dynamic_form_repository.dart';

void registerDynamicFormRepository(GetIt getIt) {
  getIt.registerLazySingleton<DynamicFormRepository>(
    () => DataDynamicFormRepository(getIt<DynamicFormRemoteDataSource>()),
  );
}

// END GENERATED
