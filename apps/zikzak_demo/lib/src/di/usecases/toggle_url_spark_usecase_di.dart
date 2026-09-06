// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_spark_repository.dart';
import '../../domain/usecases/url_spark/toggle_url_spark_usecase.dart';

void registerToggleUrlSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleUrlSparkUseCase>(
    () => ToggleUrlSparkUseCase(getIt<UrlSparkRepository>()),
  );
}

// END GENERATED
