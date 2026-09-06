// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/metric_detail_repository.dart';
import '../../domain/usecases/metric_detail/get_metric_detail_usecase.dart';

void registerGetMetricDetailUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetMetricDetailUseCase>(
    () => GetMetricDetailUseCase(getIt<MetricDetailRepository>()),
  );
}

// END GENERATED
