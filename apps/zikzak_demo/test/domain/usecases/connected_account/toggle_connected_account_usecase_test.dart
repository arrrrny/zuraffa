// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/connected_account/connected_account_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/connected_account/connected_account_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/connected_account_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_connected_account_repository.dart';
import 'package:zikzak_demo/src/domain/entities/connected_account/connected_account.dart';
import 'package:zikzak_demo/src/domain/repositories/connected_account_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/connected_account/toggle_connected_account_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingConnectedAccountDataSource
    with Loggable, FailureHandler
    implements ConnectedAccountDataSource {
  @override
  Future<ConnectedAccount> get(QueryParams<ConnectedAccount> params) {
    throw (Exception('ThrowingConnectedAccountDataSource.get'));
  }

  @override
  Future<List<ConnectedAccount>> getList(
    ListQueryParams<ConnectedAccount> params,
  ) {
    throw (Exception('ThrowingConnectedAccountDataSource.getList'));
  }

  @override
  Future<ConnectedAccount> create(ConnectedAccount entity) {
    throw (Exception('ThrowingConnectedAccountDataSource.create'));
  }

  @override
  Future<ConnectedAccount> update(
    UpdateParams<String, ConnectedAccountPatch> params,
  ) {
    throw (Exception('ThrowingConnectedAccountDataSource.update'));
  }

  @override
  Future<ConnectedAccount> toggle(
    ToggleParams<String, Field<ConnectedAccount, dynamic>> params,
  ) {
    throw (Exception('ThrowingConnectedAccountDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingConnectedAccountDataSource.delete'));
  }

  @override
  Stream<ConnectedAccount> watch(QueryParams<ConnectedAccount> params) {
    throw (Exception('ThrowingConnectedAccountDataSource.watch'));
  }

  @override
  Stream<List<ConnectedAccount>> watchList(
    ListQueryParams<ConnectedAccount> params,
  ) {
    throw (Exception('ThrowingConnectedAccountDataSource.watchList'));
  }
}

void main() {
  late ToggleConnectedAccountUseCase useCase;
  late ToggleConnectedAccountUseCase throwingUseCase;
  late DataConnectedAccountRepository repository;
  late DataConnectedAccountRepository throwingRepository;
  late ConnectedAccountMockDataSource mockDataSource;
  late ThrowingConnectedAccountDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ConnectedAccountMockDataSource();
    throwingDataSource = ThrowingConnectedAccountDataSource();
    repository = DataConnectedAccountRepository(mockDataSource);
    throwingRepository = DataConnectedAccountRepository(throwingDataSource);
    useCase = ToggleConnectedAccountUseCase(repository);
    throwingUseCase = ToggleConnectedAccountUseCase(throwingRepository);
  });
  group('ToggleConnectedAccountUseCase', () {
    final tConnectedAccount = ConnectedAccountMockData.sampleConnectedAccount;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<ConnectedAccount, dynamic>>(
          id: tConnectedAccount.id,
          field: ConnectedAccountFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<ConnectedAccount, dynamic>>(
          id: tConnectedAccount.id,
          field: ConnectedAccountFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
