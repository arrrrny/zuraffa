// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_check_invoice_repository.dart';
import '../../domain/usecases/price_check_invoice/update_price_check_invoice_usecase.dart';

void registerUpdatePriceCheckInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdatePriceCheckInvoiceUseCase>(
    () => UpdatePriceCheckInvoiceUseCase(getIt<PriceCheckInvoiceRepository>()),
  );
}

// END GENERATED
