// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/dynamic_form_field/dynamic_form_field_remote_datasource.dart';
import '../../data/repositories/data_dynamic_form_field_repository.dart';
import '../../domain/repositories/dynamic_form_field_repository.dart';

void registerDynamicFormFieldRepository(GetIt getIt) {
  getIt.registerLazySingleton<DynamicFormFieldRepository>(
    () => DataDynamicFormFieldRepository(
      getIt<DynamicFormFieldRemoteDataSource>(),
    ),
  );
}

// END GENERATED
