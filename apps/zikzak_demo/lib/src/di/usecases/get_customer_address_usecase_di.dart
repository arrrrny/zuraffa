// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_address_repository.dart';
import '../../domain/usecases/customer_address/get_customer_address_usecase.dart';

void registerGetCustomerAddressUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetCustomerAddressUseCase>(
    () => GetCustomerAddressUseCase(getIt<CustomerAddressRepository>()),
  );
}

// END GENERATED
