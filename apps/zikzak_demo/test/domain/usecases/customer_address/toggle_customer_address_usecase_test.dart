// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/customer_address/customer_address_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/customer_address/customer_address_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/customer_address_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_customer_address_repository.dart';
import 'package:zikzak_demo/src/domain/entities/customer_address/customer_address.dart';
import 'package:zikzak_demo/src/domain/repositories/customer_address_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/customer_address/toggle_customer_address_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingCustomerAddressDataSource
    with Loggable, FailureHandler
    implements CustomerAddressDataSource {
  @override
  Future<CustomerAddress> get(QueryParams<CustomerAddress> params) {
    throw (Exception('ThrowingCustomerAddressDataSource.get'));
  }

  @override
  Future<List<CustomerAddress>> getList(
    ListQueryParams<CustomerAddress> params,
  ) {
    throw (Exception('ThrowingCustomerAddressDataSource.getList'));
  }

  @override
  Future<CustomerAddress> create(CustomerAddress entity) {
    throw (Exception('ThrowingCustomerAddressDataSource.create'));
  }

  @override
  Future<CustomerAddress> update(
    UpdateParams<String, CustomerAddressPatch> params,
  ) {
    throw (Exception('ThrowingCustomerAddressDataSource.update'));
  }

  @override
  Future<CustomerAddress> toggle(
    ToggleParams<String, Field<CustomerAddress, dynamic>> params,
  ) {
    throw (Exception('ThrowingCustomerAddressDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingCustomerAddressDataSource.delete'));
  }

  @override
  Stream<CustomerAddress> watch(QueryParams<CustomerAddress> params) {
    throw (Exception('ThrowingCustomerAddressDataSource.watch'));
  }

  @override
  Stream<List<CustomerAddress>> watchList(
    ListQueryParams<CustomerAddress> params,
  ) {
    throw (Exception('ThrowingCustomerAddressDataSource.watchList'));
  }
}

void main() {
  late ToggleCustomerAddressUseCase useCase;
  late ToggleCustomerAddressUseCase throwingUseCase;
  late DataCustomerAddressRepository repository;
  late DataCustomerAddressRepository throwingRepository;
  late CustomerAddressMockDataSource mockDataSource;
  late ThrowingCustomerAddressDataSource throwingDataSource;
  setUp(() {
    mockDataSource = CustomerAddressMockDataSource();
    throwingDataSource = ThrowingCustomerAddressDataSource();
    repository = DataCustomerAddressRepository(mockDataSource);
    throwingRepository = DataCustomerAddressRepository(throwingDataSource);
    useCase = ToggleCustomerAddressUseCase(repository);
    throwingUseCase = ToggleCustomerAddressUseCase(throwingRepository);
  });
  group('ToggleCustomerAddressUseCase', () {
    final tCustomerAddress = CustomerAddressMockData.sampleCustomerAddress;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<CustomerAddress, dynamic>>(
          id: tCustomerAddress.id,
          field: CustomerAddressFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<CustomerAddress, dynamic>>(
          id: tCustomerAddress.id,
          field: CustomerAddressFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
