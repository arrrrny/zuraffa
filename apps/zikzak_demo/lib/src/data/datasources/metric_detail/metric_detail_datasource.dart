// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/metric_detail/metric_detail.dart';

abstract class MetricDetailDataSource with Loggable, FailureHandler {
  Future<MetricDetail> get(QueryParams<MetricDetail> params);
  Future<MetricDetail> update(UpdateParams<String, MetricDetailPatch> params);
  Future<MetricDetail> toggle(
    ToggleParams<String, Field<MetricDetail, dynamic>> params,
  );
}

// END GENERATED
