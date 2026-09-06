// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/customer_address/customer_address.dart';

abstract class CustomerAddressDataSource with Loggable, FailureHandler {
  Future<CustomerAddress> get(QueryParams<CustomerAddress> params);
  Future<CustomerAddress> update(
    UpdateParams<String, CustomerAddressPatch> params,
  );
  Future<CustomerAddress> toggle(
    ToggleParams<String, Field<CustomerAddress, dynamic>> params,
  );
}

// END GENERATED
