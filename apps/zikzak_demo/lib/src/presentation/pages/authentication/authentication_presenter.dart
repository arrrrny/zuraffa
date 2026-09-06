// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/authentication/authentication.dart';
import '../../../domain/usecases/authentication/get_authentication_usecase.dart';
import '../../../domain/usecases/authentication/toggle_authentication_usecase.dart';
import '../../../domain/usecases/authentication/update_authentication_usecase.dart';

class AuthenticationPresenter extends Presenter {
  AuthenticationPresenter() {
    _getAuthentication = registerUseCase(getIt<GetAuthenticationUseCase>());
    _updateAuthentication = registerUseCase(
      getIt<UpdateAuthenticationUseCase>(),
    );
    _toggleAuthentication = registerUseCase(
      getIt<ToggleAuthenticationUseCase>(),
    );
  }

  late final GetAuthenticationUseCase _getAuthentication;

  late final UpdateAuthenticationUseCase _updateAuthentication;

  late final ToggleAuthenticationUseCase _toggleAuthentication;

  Future<Result<Authentication, AppFailure>> getAuthentication(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getAuthentication.call(
      QueryParams<Authentication>(filter: Eq(AuthenticationFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Authentication, AppFailure>> updateAuthentication(
    String id,
    AuthenticationPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateAuthentication.call(
      UpdateParams<String, AuthenticationPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Authentication, AppFailure>> toggleAuthentication(
    String id,
    Field<Authentication, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleAuthentication.call(
      ToggleParams<String, Field<Authentication, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
