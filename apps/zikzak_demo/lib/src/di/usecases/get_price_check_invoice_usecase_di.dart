// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_check_invoice_repository.dart';
import '../../domain/usecases/price_check_invoice/get_price_check_invoice_usecase.dart';

void registerGetPriceCheckInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetPriceCheckInvoiceUseCase>(
    () => GetPriceCheckInvoiceUseCase(getIt<PriceCheckInvoiceRepository>()),
  );
}

// END GENERATED
