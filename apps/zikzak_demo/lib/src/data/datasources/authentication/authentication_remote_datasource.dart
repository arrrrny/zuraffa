// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/authentication/authentication.dart';
import 'authentication_datasource.dart';

class AuthenticationRemoteDataSource
    with Loggable, FailureHandler
    implements AuthenticationDataSource {
  @override
  Future<Authentication> get(QueryParams<Authentication> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Authentication> update(
    UpdateParams<String, AuthenticationPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Authentication> toggle(
    ToggleParams<String, Field<Authentication, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
