// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/customer/customer.dart';
import 'customer_datasource.dart';

class CustomerRemoteDataSource
    with Loggable, FailureHandler
    implements CustomerDataSource {
  @override
  Future<Customer> get(QueryParams<Customer> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Customer> update(UpdateParams<String, CustomerPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Customer> toggle(
    ToggleParams<String, Field<Customer, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
