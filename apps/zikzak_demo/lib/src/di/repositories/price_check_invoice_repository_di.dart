// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/price_check_invoice/price_check_invoice_remote_datasource.dart';
import '../../data/repositories/data_price_check_invoice_repository.dart';
import '../../domain/repositories/price_check_invoice_repository.dart';

void registerPriceCheckInvoiceRepository(GetIt getIt) {
  getIt.registerLazySingleton<PriceCheckInvoiceRepository>(
    () => DataPriceCheckInvoiceRepository(
      getIt<PriceCheckInvoiceRemoteDataSource>(),
    ),
  );
}

// END GENERATED
