// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/auth_request/auth_request.dart';

abstract class AuthRequestDataSource with Loggable, FailureHandler {
  Future<AuthRequest> get(QueryParams<AuthRequest> params);
  Future<AuthRequest> update(UpdateParams<String, AuthRequestPatch> params);
  Future<AuthRequest> toggle(
    ToggleParams<String, Field<AuthRequest, dynamic>> params,
  );
}

// END GENERATED
