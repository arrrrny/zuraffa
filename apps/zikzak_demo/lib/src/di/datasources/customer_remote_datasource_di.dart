// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/customer/customer_remote_datasource.dart';

void registerCustomerRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSource(),
  );
}

// END GENERATED
