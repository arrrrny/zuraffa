// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/user/user.dart';
import 'user_presenter.dart';

class UserController extends Controller {
  UserController(this._presenter);

  final UserPresenter _presenter;

  Future<void> getUser(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getUser(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateUser(
    String id,
    UserPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateUser(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleUser(
    String id,
    Field<User, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleUser(
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
