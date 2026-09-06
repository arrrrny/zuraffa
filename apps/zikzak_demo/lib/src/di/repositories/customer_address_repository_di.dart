// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/customer_address/customer_address_remote_datasource.dart';
import '../../data/repositories/data_customer_address_repository.dart';
import '../../domain/repositories/customer_address_repository.dart';

void registerCustomerAddressRepository(GetIt getIt) {
  getIt.registerLazySingleton<CustomerAddressRepository>(
    () =>
        DataCustomerAddressRepository(getIt<CustomerAddressRemoteDataSource>()),
  );
}

// END GENERATED
