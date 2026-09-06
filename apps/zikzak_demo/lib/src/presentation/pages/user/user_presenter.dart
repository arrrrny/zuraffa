// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/user/user.dart';
import '../../../domain/usecases/user/get_user_usecase.dart';
import '../../../domain/usecases/user/toggle_user_usecase.dart';
import '../../../domain/usecases/user/update_user_usecase.dart';

class UserPresenter extends Presenter {
  UserPresenter() {
    _getUser = registerUseCase(getIt<GetUserUseCase>());
    _updateUser = registerUseCase(getIt<UpdateUserUseCase>());
    _toggleUser = registerUseCase(getIt<ToggleUserUseCase>());
  }

  late final GetUserUseCase _getUser;

  late final UpdateUserUseCase _updateUser;

  late final ToggleUserUseCase _toggleUser;

  Future<Result<User, AppFailure>> getUser(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getUser.call(
      QueryParams<User>(filter: Eq(UserFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<User, AppFailure>> updateUser(
    String id,
    UserPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateUser.call(
      UpdateParams<String, UserPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<User, AppFailure>> toggleUser(
    String id,
    Field<User, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleUser.call(
      ToggleParams<String, Field<User, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
