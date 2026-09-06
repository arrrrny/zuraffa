// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/url_spark/url_spark.dart';
import 'url_spark_presenter.dart';

class UrlSparkController extends Controller {
  UrlSparkController(this._presenter);

  final UrlSparkPresenter _presenter;

  Future<void> getUrlSpark(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getUrlSpark(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateUrlSpark(
    String id,
    UrlSparkPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateUrlSpark(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleUrlSpark(
    String id,
    Field<UrlSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleUrlSpark(
      id,
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
