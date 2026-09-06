// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/auth_request/auth_request.dart';
import 'auth_request_datasource.dart';

class AuthRequestRemoteDataSource
    with Loggable, FailureHandler
    implements AuthRequestDataSource {
  @override
  Future<AuthRequest> get(QueryParams<AuthRequest> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<AuthRequest> update(
    UpdateParams<String, AuthRequestPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<AuthRequest> toggle(
    ToggleParams<String, Field<AuthRequest, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
