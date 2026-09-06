// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_spark_repository.dart';
import '../../domain/usecases/url_spark/get_url_spark_usecase.dart';

void registerGetUrlSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetUrlSparkUseCase>(
    () => GetUrlSparkUseCase(getIt<UrlSparkRepository>()),
  );
}

// END GENERATED
