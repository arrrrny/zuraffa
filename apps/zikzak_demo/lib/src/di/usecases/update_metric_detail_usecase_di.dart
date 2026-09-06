// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/metric_detail_repository.dart';
import '../../domain/usecases/metric_detail/update_metric_detail_usecase.dart';

void registerUpdateMetricDetailUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateMetricDetailUseCase>(
    () => UpdateMetricDetailUseCase(getIt<MetricDetailRepository>()),
  );
}

// END GENERATED
