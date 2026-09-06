// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/customer_address/customer_address.dart';
import 'customer_address_datasource.dart';

class CustomerAddressRemoteDataSource
    with Loggable, FailureHandler
    implements CustomerAddressDataSource {
  @override
  Future<CustomerAddress> get(QueryParams<CustomerAddress> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<CustomerAddress> update(
    UpdateParams<String, CustomerAddressPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<CustomerAddress> toggle(
    ToggleParams<String, Field<CustomerAddress, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
