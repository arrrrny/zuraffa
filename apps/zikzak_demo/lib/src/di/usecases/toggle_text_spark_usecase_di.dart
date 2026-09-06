// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_spark_repository.dart';
import '../../domain/usecases/text_spark/toggle_text_spark_usecase.dart';

void registerToggleTextSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleTextSparkUseCase>(
    () => ToggleTextSparkUseCase(getIt<TextSparkRepository>()),
  );
}

// END GENERATED
