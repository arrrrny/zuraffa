// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/user/user.dart';
import 'user_datasource.dart';

class UserRemoteDataSource
    with Loggable, FailureHandler
    implements UserDataSource {
  @override
  Future<User> get(QueryParams<User> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<User> update(UpdateParams<String, UserPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<User> toggle(ToggleParams<String, Field<User, dynamic>> params) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
