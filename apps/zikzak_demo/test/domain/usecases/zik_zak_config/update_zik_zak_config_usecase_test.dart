// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak_config/zik_zak_config_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak_config/zik_zak_config_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/zik_zak_config_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_zik_zak_config_repository.dart';
import 'package:zikzak_demo/src/domain/entities/zik_zak_config/zik_zak_config.dart';
import 'package:zikzak_demo/src/domain/repositories/zik_zak_config_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/zik_zak_config/update_zik_zak_config_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingZikZakConfigDataSource
    with Loggable, FailureHandler
    implements ZikZakConfigDataSource {
  @override
  Future<ZikZakConfig> get(QueryParams<ZikZakConfig> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.get'));
  }

  @override
  Future<List<ZikZakConfig>> getList(ListQueryParams<ZikZakConfig> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.getList'));
  }

  @override
  Future<ZikZakConfig> create(ZikZakConfig entity) {
    throw (Exception('ThrowingZikZakConfigDataSource.create'));
  }

  @override
  Future<ZikZakConfig> update(UpdateParams<String, ZikZakConfigPatch> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.update'));
  }

  @override
  Future<ZikZakConfig> toggle(
    ToggleParams<String, Field<ZikZakConfig, dynamic>> params,
  ) {
    throw (Exception('ThrowingZikZakConfigDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.delete'));
  }

  @override
  Stream<ZikZakConfig> watch(QueryParams<ZikZakConfig> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.watch'));
  }

  @override
  Stream<List<ZikZakConfig>> watchList(ListQueryParams<ZikZakConfig> params) {
    throw (Exception('ThrowingZikZakConfigDataSource.watchList'));
  }
}

void main() {
  late UpdateZikZakConfigUseCase useCase;
  late UpdateZikZakConfigUseCase throwingUseCase;
  late DataZikZakConfigRepository repository;
  late DataZikZakConfigRepository throwingRepository;
  late ZikZakConfigMockDataSource mockDataSource;
  late ThrowingZikZakConfigDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ZikZakConfigMockDataSource();
    throwingDataSource = ThrowingZikZakConfigDataSource();
    repository = DataZikZakConfigRepository(mockDataSource);
    throwingRepository = DataZikZakConfigRepository(throwingDataSource);
    useCase = UpdateZikZakConfigUseCase(repository);
    throwingUseCase = UpdateZikZakConfigUseCase(throwingRepository);
  });
  group('UpdateZikZakConfigUseCase', () {
    final tZikZakConfig = ZikZakConfigMockData.sampleZikZakConfig;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, ZikZakConfigPatch>(
          id: tZikZakConfig.id,
          data: ZikZakConfigPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, ZikZakConfigPatch>(
          id: tZikZakConfig.id,
          data: ZikZakConfigPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
