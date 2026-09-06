// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_check_invoice_repository.dart';
import '../../domain/usecases/price_check_invoice/toggle_price_check_invoice_usecase.dart';

void registerTogglePriceCheckInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<TogglePriceCheckInvoiceUseCase>(
    () => TogglePriceCheckInvoiceUseCase(getIt<PriceCheckInvoiceRepository>()),
  );
}

// END GENERATED
