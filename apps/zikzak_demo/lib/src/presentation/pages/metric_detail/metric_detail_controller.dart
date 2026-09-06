// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/metric_detail/metric_detail.dart';
import 'metric_detail_presenter.dart';

class MetricDetailController extends Controller {
  MetricDetailController(this._presenter);

  final MetricDetailPresenter _presenter;

  Future<void> getMetricDetail(String name, [CancelToken? cancelToken]) async {
    final result = await _presenter.getMetricDetail(name, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateMetricDetail(
    String name,
    MetricDetailPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateMetricDetail(name, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleMetricDetail(
    String name,
    Field<MetricDetail, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleMetricDetail(
      name,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
