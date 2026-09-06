// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/error_log/error_log.dart';
import '../../../domain/usecases/error_log/get_error_log_usecase.dart';
import '../../../domain/usecases/error_log/toggle_error_log_usecase.dart';
import '../../../domain/usecases/error_log/update_error_log_usecase.dart';

class ErrorLogPresenter extends Presenter {
  ErrorLogPresenter() {
    _getErrorLog = registerUseCase(getIt<GetErrorLogUseCase>());
    _updateErrorLog = registerUseCase(getIt<UpdateErrorLogUseCase>());
    _toggleErrorLog = registerUseCase(getIt<ToggleErrorLogUseCase>());
  }

  late final GetErrorLogUseCase _getErrorLog;

  late final UpdateErrorLogUseCase _updateErrorLog;

  late final ToggleErrorLogUseCase _toggleErrorLog;

  Future<Result<ErrorLog, AppFailure>> getErrorLog(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getErrorLog.call(
      QueryParams<ErrorLog>(filter: Eq(ErrorLogFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ErrorLog, AppFailure>> updateErrorLog(
    String id,
    ErrorLogPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateErrorLog.call(
      UpdateParams<String, ErrorLogPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ErrorLog, AppFailure>> toggleErrorLog(
    String id,
    Field<ErrorLog, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleErrorLog.call(
      ToggleParams<String, Field<ErrorLog, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
