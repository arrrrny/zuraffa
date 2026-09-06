// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/metric_detail/metric_detail.dart';
import 'metric_detail_datasource.dart';

class MetricDetailRemoteDataSource
    with Loggable, FailureHandler
    implements MetricDetailDataSource {
  @override
  Future<MetricDetail> get(QueryParams<MetricDetail> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<MetricDetail> update(
    UpdateParams<String, MetricDetailPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<MetricDetail> toggle(
    ToggleParams<String, Field<MetricDetail, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
