// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/connected_account/connected_account.dart';
import 'connected_account_datasource.dart';

class ConnectedAccountRemoteDataSource
    with Loggable, FailureHandler
    implements ConnectedAccountDataSource {
  @override
  Future<ConnectedAccount> get(QueryParams<ConnectedAccount> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ConnectedAccount> update(
    UpdateParams<String, ConnectedAccountPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ConnectedAccount> toggle(
    ToggleParams<String, Field<ConnectedAccount, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
