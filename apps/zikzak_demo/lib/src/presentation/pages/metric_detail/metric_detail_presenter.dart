// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/metric_detail/metric_detail.dart';
import '../../../domain/usecases/metric_detail/get_metric_detail_usecase.dart';
import '../../../domain/usecases/metric_detail/toggle_metric_detail_usecase.dart';
import '../../../domain/usecases/metric_detail/update_metric_detail_usecase.dart';

class MetricDetailPresenter extends Presenter {
  MetricDetailPresenter() {
    _getMetricDetail = registerUseCase(getIt<GetMetricDetailUseCase>());
    _updateMetricDetail = registerUseCase(getIt<UpdateMetricDetailUseCase>());
    _toggleMetricDetail = registerUseCase(getIt<ToggleMetricDetailUseCase>());
  }

  late final GetMetricDetailUseCase _getMetricDetail;

  late final UpdateMetricDetailUseCase _updateMetricDetail;

  late final ToggleMetricDetailUseCase _toggleMetricDetail;

  Future<Result<MetricDetail, AppFailure>> getMetricDetail(
    String name, [
    CancelToken? cancelToken,
  ]) {
    return _getMetricDetail.call(
      QueryParams<MetricDetail>(filter: Eq(MetricDetailFields.name, name)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<MetricDetail, AppFailure>> updateMetricDetail(
    String name,
    MetricDetailPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateMetricDetail.call(
      UpdateParams<String, MetricDetailPatch>(id: name, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<MetricDetail, AppFailure>> toggleMetricDetail(
    String name,
    Field<MetricDetail, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleMetricDetail.call(
      ToggleParams<String, Field<MetricDetail, dynamic>>(
        id: name,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
