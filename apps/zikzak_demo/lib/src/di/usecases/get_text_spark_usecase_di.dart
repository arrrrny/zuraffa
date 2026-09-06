// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_spark_repository.dart';
import '../../domain/usecases/text_spark/get_text_spark_usecase.dart';

void registerGetTextSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetTextSparkUseCase>(
    () => GetTextSparkUseCase(getIt<TextSparkRepository>()),
  );
}

// END GENERATED
