// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/price_check_invoice/price_check_invoice_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/price_check_invoice/price_check_invoice_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/price_check_invoice_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_price_check_invoice_repository.dart';
import 'package:zikzak_demo/src/domain/entities/price_check_invoice/price_check_invoice.dart';
import 'package:zikzak_demo/src/domain/repositories/price_check_invoice_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/price_check_invoice/get_price_check_invoice_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingPriceCheckInvoiceDataSource
    with Loggable, FailureHandler
    implements PriceCheckInvoiceDataSource {
  @override
  Future<PriceCheckInvoice> get(QueryParams<PriceCheckInvoice> params) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.get'));
  }

  @override
  Future<List<PriceCheckInvoice>> getList(
    ListQueryParams<PriceCheckInvoice> params,
  ) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.getList'));
  }

  @override
  Future<PriceCheckInvoice> create(PriceCheckInvoice entity) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.create'));
  }

  @override
  Future<PriceCheckInvoice> update(
    UpdateParams<String, PriceCheckInvoicePatch> params,
  ) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.update'));
  }

  @override
  Future<PriceCheckInvoice> toggle(
    ToggleParams<String, Field<PriceCheckInvoice, dynamic>> params,
  ) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.delete'));
  }

  @override
  Stream<PriceCheckInvoice> watch(QueryParams<PriceCheckInvoice> params) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.watch'));
  }

  @override
  Stream<List<PriceCheckInvoice>> watchList(
    ListQueryParams<PriceCheckInvoice> params,
  ) {
    throw (Exception('ThrowingPriceCheckInvoiceDataSource.watchList'));
  }
}

void main() {
  late GetPriceCheckInvoiceUseCase useCase;
  late GetPriceCheckInvoiceUseCase throwingUseCase;
  late DataPriceCheckInvoiceRepository repository;
  late DataPriceCheckInvoiceRepository throwingRepository;
  late PriceCheckInvoiceMockDataSource mockDataSource;
  late ThrowingPriceCheckInvoiceDataSource throwingDataSource;
  setUp(() {
    mockDataSource = PriceCheckInvoiceMockDataSource();
    throwingDataSource = ThrowingPriceCheckInvoiceDataSource();
    repository = DataPriceCheckInvoiceRepository(mockDataSource);
    throwingRepository = DataPriceCheckInvoiceRepository(throwingDataSource);
    useCase = GetPriceCheckInvoiceUseCase(repository);
    throwingUseCase = GetPriceCheckInvoiceUseCase(throwingRepository);
  });
  group('GetPriceCheckInvoiceUseCase', () {
    final tPriceCheckInvoice =
        PriceCheckInvoiceMockData.samplePriceCheckInvoice;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<PriceCheckInvoice>(
          filter: Eq(PriceCheckInvoiceFields.id, tPriceCheckInvoice.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tPriceCheckInvoice),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<PriceCheckInvoice>(
          filter: Eq(PriceCheckInvoiceFields.id, tPriceCheckInvoice.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
