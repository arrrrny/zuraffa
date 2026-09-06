// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/error_log/error_log.dart';

abstract class ErrorLogDataSource with Loggable, FailureHandler {
  Future<ErrorLog> get(QueryParams<ErrorLog> params);
  Future<ErrorLog> update(UpdateParams<String, ErrorLogPatch> params);
  Future<ErrorLog> toggle(
    ToggleParams<String, Field<ErrorLog, dynamic>> params,
  );
}

// END GENERATED
