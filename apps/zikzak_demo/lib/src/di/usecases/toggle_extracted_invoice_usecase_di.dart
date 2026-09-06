// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/extracted_invoice_repository.dart';
import '../../domain/usecases/extracted_invoice/toggle_extracted_invoice_usecase.dart';

void registerToggleExtractedInvoiceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleExtractedInvoiceUseCase>(
    () => ToggleExtractedInvoiceUseCase(getIt<ExtractedInvoiceRepository>()),
  );
}

// END GENERATED
