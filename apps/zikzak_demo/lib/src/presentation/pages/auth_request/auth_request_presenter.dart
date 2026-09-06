// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/auth_request/auth_request.dart';
import '../../../domain/usecases/auth_request/get_auth_request_usecase.dart';
import '../../../domain/usecases/auth_request/toggle_auth_request_usecase.dart';
import '../../../domain/usecases/auth_request/update_auth_request_usecase.dart';

class AuthRequestPresenter extends Presenter {
  AuthRequestPresenter() {
    _getAuthRequest = registerUseCase(getIt<GetAuthRequestUseCase>());
    _updateAuthRequest = registerUseCase(getIt<UpdateAuthRequestUseCase>());
    _toggleAuthRequest = registerUseCase(getIt<ToggleAuthRequestUseCase>());
  }

  late final GetAuthRequestUseCase _getAuthRequest;

  late final UpdateAuthRequestUseCase _updateAuthRequest;

  late final ToggleAuthRequestUseCase _toggleAuthRequest;

  Future<Result<AuthRequest, AppFailure>> getAuthRequest(
    String email, [
    CancelToken? cancelToken,
  ]) {
    return _getAuthRequest.call(
      QueryParams<AuthRequest>(filter: Eq(AuthRequestFields.email, email)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AuthRequest, AppFailure>> updateAuthRequest(
    String email,
    AuthRequestPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateAuthRequest.call(
      UpdateParams<String, AuthRequestPatch>(id: email, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AuthRequest, AppFailure>> toggleAuthRequest(
    String email,
    Field<AuthRequest, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleAuthRequest.call(
      ToggleParams<String, Field<AuthRequest, dynamic>>(
        id: email,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
