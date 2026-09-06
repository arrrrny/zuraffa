// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/authentication/authentication.dart';
import 'authentication_presenter.dart';

class AuthenticationController extends Controller {
  AuthenticationController(this._presenter);

  final AuthenticationPresenter _presenter;

  Future<void> getAuthentication(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getAuthentication(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateAuthentication(
    String id,
    AuthenticationPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateAuthentication(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleAuthentication(
    String id,
    Field<Authentication, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleAuthentication(
      id,
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
