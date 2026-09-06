// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/customer_repository.dart';
import '../../domain/usecases/customer/update_customer_usecase.dart';

void registerUpdateCustomerUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateCustomerUseCase>(
    () => UpdateCustomerUseCase(getIt<CustomerRepository>()),
  );
}

// END GENERATED
