// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/metric_detail_repository.dart';
import '../../domain/usecases/metric_detail/toggle_metric_detail_usecase.dart';

void registerToggleMetricDetailUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleMetricDetailUseCase>(
    () => ToggleMetricDetailUseCase(getIt<MetricDetailRepository>()),
  );
}

// END GENERATED
