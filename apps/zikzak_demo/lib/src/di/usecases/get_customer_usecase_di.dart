// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer/get_customer_usecase.dart';

void registerGetCustomerUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetCustomerUseCase>(
    () => GetCustomerUseCase(getIt<CustomerRepository>()),
  );
}

// END GENERATED
