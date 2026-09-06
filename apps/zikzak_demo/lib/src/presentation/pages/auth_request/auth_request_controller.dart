// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/auth_request/auth_request.dart';
import 'auth_request_presenter.dart';

class AuthRequestController extends Controller {
  AuthRequestController(this._presenter);

  final AuthRequestPresenter _presenter;

  Future<void> getAuthRequest(String email, [CancelToken? cancelToken]) async {
    final result = await _presenter.getAuthRequest(email, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateAuthRequest(
    String email,
    AuthRequestPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateAuthRequest(email, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleAuthRequest(
    String email,
    Field<AuthRequest, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleAuthRequest(
      email,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
