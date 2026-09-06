// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/extracted_invoice/extracted_invoice_remote_datasource.dart';
import '../../data/repositories/data_extracted_invoice_repository.dart';
import '../../domain/repositories/extracted_invoice_repository.dart';

void registerExtractedInvoiceRepository(GetIt getIt) {
  getIt.registerLazySingleton<ExtractedInvoiceRepository>(
    () => DataExtractedInvoiceRepository(
      getIt<ExtractedInvoiceRemoteDataSource>(),
    ),
  );
}

// END GENERATED
