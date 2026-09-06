// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_spark_repository.dart';
import '../../domain/usecases/text_spark/update_text_spark_usecase.dart';

void registerUpdateTextSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateTextSparkUseCase>(
    () => UpdateTextSparkUseCase(getIt<TextSparkRepository>()),
  );
}

// END GENERATED
