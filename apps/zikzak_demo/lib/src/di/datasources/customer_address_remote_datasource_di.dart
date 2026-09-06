// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/customer_address/customer_address_remote_datasource.dart';

void registerCustomerAddressRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<CustomerAddressRemoteDataSource>(
    () => CustomerAddressRemoteDataSource(),
  );
}

// END GENERATED
