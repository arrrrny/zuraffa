// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_address_repository.dart';
import '../../domain/usecases/customer_address/update_customer_address_usecase.dart';

void registerUpdateCustomerAddressUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateCustomerAddressUseCase>(
    () => UpdateCustomerAddressUseCase(getIt<CustomerAddressRepository>()),
  );
}

// END GENERATED
