// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/app_config/app_config_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/app_config/app_config_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/app_config_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_app_config_repository.dart';
import 'package:zikzak_demo/src/domain/entities/app_config/app_config.dart';
import 'package:zikzak_demo/src/domain/repositories/app_config_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/app_config/toggle_app_config_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingAppConfigDataSource
    with Loggable, FailureHandler
    implements AppConfigDataSource {
  @override
  Future<AppConfig> get(QueryParams<AppConfig> params) {
    throw (Exception('ThrowingAppConfigDataSource.get'));
  }

  @override
  Future<List<AppConfig>> getList(ListQueryParams<AppConfig> params) {
    throw (Exception('ThrowingAppConfigDataSource.getList'));
  }

  @override
  Future<AppConfig> create(AppConfig entity) {
    throw (Exception('ThrowingAppConfigDataSource.create'));
  }

  @override
  Future<AppConfig> update(UpdateParams<String, AppConfigPatch> params) {
    throw (Exception('ThrowingAppConfigDataSource.update'));
  }

  @override
  Future<AppConfig> toggle(
    ToggleParams<String, Field<AppConfig, dynamic>> params,
  ) {
    throw (Exception('ThrowingAppConfigDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingAppConfigDataSource.delete'));
  }

  @override
  Stream<AppConfig> watch(QueryParams<AppConfig> params) {
    throw (Exception('ThrowingAppConfigDataSource.watch'));
  }

  @override
  Stream<List<AppConfig>> watchList(ListQueryParams<AppConfig> params) {
    throw (Exception('ThrowingAppConfigDataSource.watchList'));
  }
}

void main() {
  late ToggleAppConfigUseCase useCase;
  late ToggleAppConfigUseCase throwingUseCase;
  late DataAppConfigRepository repository;
  late DataAppConfigRepository throwingRepository;
  late AppConfigMockDataSource mockDataSource;
  late ThrowingAppConfigDataSource throwingDataSource;
  setUp(() {
    mockDataSource = AppConfigMockDataSource();
    throwingDataSource = ThrowingAppConfigDataSource();
    repository = DataAppConfigRepository(mockDataSource);
    throwingRepository = DataAppConfigRepository(throwingDataSource);
    useCase = ToggleAppConfigUseCase(repository);
    throwingUseCase = ToggleAppConfigUseCase(throwingRepository);
  });
  group('ToggleAppConfigUseCase', () {
    final tAppConfig = AppConfigMockData.sampleAppConfig;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<AppConfig, dynamic>>(
          id: tAppConfig.id,
          field: AppConfigFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<AppConfig, dynamic>>(
          id: tAppConfig.id,
          field: AppConfigFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
