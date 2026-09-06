// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/connected_account/connected_account.dart';

abstract class ConnectedAccountDataSource with Loggable, FailureHandler {
  Future<ConnectedAccount> get(QueryParams<ConnectedAccount> params);
  Future<ConnectedAccount> update(
    UpdateParams<String, ConnectedAccountPatch> params,
  );
  Future<ConnectedAccount> toggle(
    ToggleParams<String, Field<ConnectedAccount, dynamic>> params,
  );
}

// END GENERATED
