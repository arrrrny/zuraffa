// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/customer/customer.dart';

abstract class CustomerDataSource with Loggable, FailureHandler {
  Future<Customer> get(QueryParams<Customer> params);
  Future<Customer> update(UpdateParams<String, CustomerPatch> params);
  Future<Customer> toggle(
    ToggleParams<String, Field<Customer, dynamic>> params,
  );
}

// END GENERATED
