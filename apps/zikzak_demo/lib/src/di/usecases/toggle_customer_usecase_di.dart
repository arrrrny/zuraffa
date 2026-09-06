// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer/toggle_customer_usecase.dart';

void registerToggleCustomerUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleCustomerUseCase>(
    () => ToggleCustomerUseCase(getIt<CustomerRepository>()),
  );
}

// END GENERATED
