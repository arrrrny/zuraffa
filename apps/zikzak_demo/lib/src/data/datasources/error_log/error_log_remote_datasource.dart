// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/error_log/error_log.dart';
import 'error_log_datasource.dart';

class ErrorLogRemoteDataSource
    with Loggable, FailureHandler
    implements ErrorLogDataSource {
  @override
  Future<ErrorLog> get(QueryParams<ErrorLog> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ErrorLog> update(UpdateParams<String, ErrorLogPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ErrorLog> toggle(
    ToggleParams<String, Field<ErrorLog, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
