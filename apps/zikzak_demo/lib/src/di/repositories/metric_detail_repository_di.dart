// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/metric_detail/metric_detail_remote_datasource.dart';
import '../../data/repositories/data_metric_detail_repository.dart';
import '../../domain/repositories/metric_detail_repository.dart';

void registerMetricDetailRepository(GetIt getIt) {
  getIt.registerLazySingleton<MetricDetailRepository>(
    () => DataMetricDetailRepository(getIt<MetricDetailRemoteDataSource>()),
  );
}

// END GENERATED
