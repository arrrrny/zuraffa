// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/customer/customer_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/customer/customer_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/customer_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_customer_repository.dart';
import 'package:zikzak_demo/src/domain/entities/customer/customer.dart';
import 'package:zikzak_demo/src/domain/repositories/customer_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/customer/update_customer_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingCustomerDataSource
    with Loggable, FailureHandler
    implements CustomerDataSource {
  @override
  Future<Customer> get(QueryParams<Customer> params) {
    throw (Exception('ThrowingCustomerDataSource.get'));
  }

  @override
  Future<List<Customer>> getList(ListQueryParams<Customer> params) {
    throw (Exception('ThrowingCustomerDataSource.getList'));
  }

  @override
  Future<Customer> create(Customer entity) {
    throw (Exception('ThrowingCustomerDataSource.create'));
  }

  @override
  Future<Customer> update(UpdateParams<String, CustomerPatch> params) {
    throw (Exception('ThrowingCustomerDataSource.update'));
  }

  @override
  Future<Customer> toggle(
    ToggleParams<String, Field<Customer, dynamic>> params,
  ) {
    throw (Exception('ThrowingCustomerDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingCustomerDataSource.delete'));
  }

  @override
  Stream<Customer> watch(QueryParams<Customer> params) {
    throw (Exception('ThrowingCustomerDataSource.watch'));
  }

  @override
  Stream<List<Customer>> watchList(ListQueryParams<Customer> params) {
    throw (Exception('ThrowingCustomerDataSource.watchList'));
  }
}

void main() {
  late UpdateCustomerUseCase useCase;
  late UpdateCustomerUseCase throwingUseCase;
  late DataCustomerRepository repository;
  late DataCustomerRepository throwingRepository;
  late CustomerMockDataSource mockDataSource;
  late ThrowingCustomerDataSource throwingDataSource;
  setUp(() {
    mockDataSource = CustomerMockDataSource();
    throwingDataSource = ThrowingCustomerDataSource();
    repository = DataCustomerRepository(mockDataSource);
    throwingRepository = DataCustomerRepository(throwingDataSource);
    useCase = UpdateCustomerUseCase(repository);
    throwingUseCase = UpdateCustomerUseCase(throwingRepository);
  });
  group('UpdateCustomerUseCase', () {
    final tCustomer = CustomerMockData.sampleCustomer;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, CustomerPatch>(
          id: tCustomer.id,
          data: CustomerPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, CustomerPatch>(
          id: tCustomer.id,
          data: CustomerPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
