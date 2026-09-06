// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_spark_repository.dart';
import '../../domain/usecases/url_spark/update_url_spark_usecase.dart';

void registerUpdateUrlSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateUrlSparkUseCase>(
    () => UpdateUrlSparkUseCase(getIt<UrlSparkRepository>()),
  );
}

// END GENERATED
