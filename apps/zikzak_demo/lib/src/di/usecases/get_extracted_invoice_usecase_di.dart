// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/extracted_invoice_repository.dart';
import '../../domain/usecases/extracted_invoice/get_extracted_invoice_usecase.dart';

void registerGetExtractedInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetExtractedInvoiceUseCase>(
    () => GetExtractedInvoiceUseCase(getIt<ExtractedInvoiceRepository>()),
  );
}

// END GENERATED
