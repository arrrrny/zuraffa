// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/extracted_invoice/extracted_invoice_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/extracted_invoice/extracted_invoice_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/extracted_invoice_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_extracted_invoice_repository.dart';
import 'package:zikzak_demo/src/domain/entities/extracted_invoice/extracted_invoice.dart';
import 'package:zikzak_demo/src/domain/repositories/extracted_invoice_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/extracted_invoice/toggle_extracted_invoice_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingExtractedInvoiceDataSource
    with Loggable, FailureHandler
    implements ExtractedInvoiceDataSource {
  @override
  Future<ExtractedInvoice> get(QueryParams<ExtractedInvoice> params) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.get'));
  }

  @override
  Future<List<ExtractedInvoice>> getList(
    ListQueryParams<ExtractedInvoice> params,
  ) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.getList'));
  }

  @override
  Future<ExtractedInvoice> create(ExtractedInvoice entity) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.create'));
  }

  @override
  Future<ExtractedInvoice> update(
    UpdateParams<String, ExtractedInvoicePatch> params,
  ) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.update'));
  }

  @override
  Future<ExtractedInvoice> toggle(
    ToggleParams<String, Field<ExtractedInvoice, dynamic>> params,
  ) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.delete'));
  }

  @override
  Stream<ExtractedInvoice> watch(QueryParams<ExtractedInvoice> params) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.watch'));
  }

  @override
  Stream<List<ExtractedInvoice>> watchList(
    ListQueryParams<ExtractedInvoice> params,
  ) {
    throw (Exception('ThrowingExtractedInvoiceDataSource.watchList'));
  }
}

void main() {
  late ToggleExtractedInvoiceUseCase useCase;
  late ToggleExtractedInvoiceUseCase throwingUseCase;
  late DataExtractedInvoiceRepository repository;
  late DataExtractedInvoiceRepository throwingRepository;
  late ExtractedInvoiceMockDataSource mockDataSource;
  late ThrowingExtractedInvoiceDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ExtractedInvoiceMockDataSource();
    throwingDataSource = ThrowingExtractedInvoiceDataSource();
    repository = DataExtractedInvoiceRepository(mockDataSource);
    throwingRepository = DataExtractedInvoiceRepository(throwingDataSource);
    useCase = ToggleExtractedInvoiceUseCase(repository);
    throwingUseCase = ToggleExtractedInvoiceUseCase(throwingRepository);
  });
  group('ToggleExtractedInvoiceUseCase', () {
    final tExtractedInvoice = ExtractedInvoiceMockData.sampleExtractedInvoice;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<ExtractedInvoice, dynamic>>(
          id: tExtractedInvoice.id,
          field: ExtractedInvoiceFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<ExtractedInvoice, dynamic>>(
          id: tExtractedInvoice.id,
          field: ExtractedInvoiceFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
