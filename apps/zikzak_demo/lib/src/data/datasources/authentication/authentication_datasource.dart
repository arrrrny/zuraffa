// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/authentication/authentication.dart';

abstract class AuthenticationDataSource with Loggable, FailureHandler {
  Future<Authentication> get(QueryParams<Authentication> params);
  Future<Authentication> update(
    UpdateParams<String, AuthenticationPatch> params,
  );
  Future<Authentication> toggle(
    ToggleParams<String, Field<Authentication, dynamic>> params,
  );
}

// END GENERATED
