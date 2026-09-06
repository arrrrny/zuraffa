// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/user/user.dart';

abstract class UserDataSource with Loggable, FailureHandler {
  Future<User> get(QueryParams<User> params);
  Future<User> update(UpdateParams<String, UserPatch> params);
  Future<User> toggle(ToggleParams<String, Field<User, dynamic>> params);
}

// END GENERATED
