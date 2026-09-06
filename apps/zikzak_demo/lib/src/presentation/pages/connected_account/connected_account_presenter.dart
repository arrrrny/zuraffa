// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/connected_account/connected_account.dart';
import '../../../domain/usecases/connected_account/get_connected_account_usecase.dart';
import '../../../domain/usecases/connected_account/toggle_connected_account_usecase.dart';
import '../../../domain/usecases/connected_account/update_connected_account_usecase.dart';

class ConnectedAccountPresenter extends Presenter {
  ConnectedAccountPresenter() {
    _getConnectedAccount = registerUseCase(getIt<GetConnectedAccountUseCase>());
    _updateConnectedAccount = registerUseCase(
      getIt<UpdateConnectedAccountUseCase>(),
    );
    _toggleConnectedAccount = registerUseCase(
      getIt<ToggleConnectedAccountUseCase>(),
    );
  }

  late final GetConnectedAccountUseCase _getConnectedAccount;

  late final UpdateConnectedAccountUseCase _updateConnectedAccount;

  late final ToggleConnectedAccountUseCase _toggleConnectedAccount;

  Future<Result<ConnectedAccount, AppFailure>> getConnectedAccount(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getConnectedAccount.call(
      QueryParams<ConnectedAccount>(filter: Eq(ConnectedAccountFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ConnectedAccount, AppFailure>> updateConnectedAccount(
    String id,
    ConnectedAccountPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateConnectedAccount.call(
      UpdateParams<String, ConnectedAccountPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ConnectedAccount, AppFailure>> toggleConnectedAccount(
    String id,
    Field<ConnectedAccount, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleConnectedAccount.call(
      ToggleParams<String, Field<ConnectedAccount, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
