// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/text_spark/text_spark.dart';
import 'text_spark_presenter.dart';

class TextSparkController extends Controller {
  TextSparkController(this._presenter);

  final TextSparkPresenter _presenter;

  Future<void> getTextSpark(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getTextSpark(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateTextSpark(
    String id,
    TextSparkPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateTextSpark(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleTextSpark(
    String id,
    Field<TextSpark, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleTextSpark(
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
