// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/customer/customer_remote_datasource.dart';
import '../../data/repositories/data_customer_repository.dart';
import '../../domain/repositories/customer_repository.dart';

void registerCustomerRepository(GetIt getIt) {
  getIt.registerLazySingleton<CustomerRepository>(
    () => DataCustomerRepository(getIt<CustomerRemoteDataSource>()),
  );
}

// END GENERATED
