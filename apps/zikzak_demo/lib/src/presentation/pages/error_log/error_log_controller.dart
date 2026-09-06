// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/error_log/error_log.dart';
import 'error_log_presenter.dart';

class ErrorLogController extends Controller {
  ErrorLogController(this._presenter);

  final ErrorLogPresenter _presenter;

  Future<void> getErrorLog(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getErrorLog(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateErrorLog(
    String id,
    ErrorLogPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateErrorLog(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleErrorLog(
    String id,
    Field<ErrorLog, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleErrorLog(
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
