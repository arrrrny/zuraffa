// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/connected_account/connected_account.dart';
import 'connected_account_presenter.dart';

class ConnectedAccountController extends Controller {
  ConnectedAccountController(this._presenter);

  final ConnectedAccountPresenter _presenter;

  Future<void> getConnectedAccount(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getConnectedAccount(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateConnectedAccount(
    String id,
    ConnectedAccountPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateConnectedAccount(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleConnectedAccount(
    String id,
    Field<ConnectedAccount, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleConnectedAccount(
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
