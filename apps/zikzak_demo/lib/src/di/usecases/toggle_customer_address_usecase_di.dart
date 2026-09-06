// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_address_repository.dart';
import '../../domain/usecases/customer_address/toggle_customer_address_usecase.dart';

void registerToggleCustomerAddressUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleCustomerAddressUseCase>(
    () => ToggleCustomerAddressUseCase(getIt<CustomerAddressRepository>()),
  );
}

// END GENERATED
