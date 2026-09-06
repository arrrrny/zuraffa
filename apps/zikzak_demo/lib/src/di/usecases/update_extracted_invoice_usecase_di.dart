// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/extracted_invoice_repository.dart';
import '../../domain/usecases/extracted_invoice/update_extracted_invoice_usecase.dart';

void registerUpdateExtractedInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateExtractedInvoiceUseCase>(
    () => UpdateExtractedInvoiceUseCase(getIt<ExtractedInvoiceRepository>()),
  );
}

// END GENERATED
