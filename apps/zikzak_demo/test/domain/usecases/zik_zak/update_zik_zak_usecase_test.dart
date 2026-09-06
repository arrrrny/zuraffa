// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak/zik_zak_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak/zik_zak_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/zik_zak_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_zik_zak_repository.dart';
import 'package:zikzak_demo/src/domain/entities/zik_zak/zik_zak.dart';
import 'package:zikzak_demo/src/domain/repositories/zik_zak_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/zik_zak/update_zik_zak_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingZikZakDataSource
    with Loggable, FailureHandler
    implements ZikZakDataSource {
  @override
  Future<ZikZak> get(QueryParams<ZikZak> params) {
    throw (Exception('ThrowingZikZakDataSource.get'));
  }

  @override
  Future<List<ZikZak>> getList(ListQueryParams<ZikZak> params) {
    throw (Exception('ThrowingZikZakDataSource.getList'));
  }

  @override
  Future<ZikZak> create(ZikZak entity) {
    throw (Exception('ThrowingZikZakDataSource.create'));
  }

  @override
  Future<ZikZak> update(UpdateParams<String, ZikZakPatch> params) {
    throw (Exception('ThrowingZikZakDataSource.update'));
  }

  @override
  Future<ZikZak> toggle(ToggleParams<String, Field<ZikZak, dynamic>> params) {
    throw (Exception('ThrowingZikZakDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingZikZakDataSource.delete'));
  }

  @override
  Stream<ZikZak> watch(QueryParams<ZikZak> params) {
    throw (Exception('ThrowingZikZakDataSource.watch'));
  }

  @override
  Stream<List<ZikZak>> watchList(ListQueryParams<ZikZak> params) {
    throw (Exception('ThrowingZikZakDataSource.watchList'));
  }
}

void main() {
  late UpdateZikZakUseCase useCase;
  late UpdateZikZakUseCase throwingUseCase;
  late DataZikZakRepository repository;
  late DataZikZakRepository throwingRepository;
  late ZikZakMockDataSource mockDataSource;
  late ThrowingZikZakDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ZikZakMockDataSource();
    throwingDataSource = ThrowingZikZakDataSource();
    repository = DataZikZakRepository(mockDataSource);
    throwingRepository = DataZikZakRepository(throwingDataSource);
    useCase = UpdateZikZakUseCase(repository);
    throwingUseCase = UpdateZikZakUseCase(throwingRepository);
  });
  group('UpdateZikZakUseCase', () {
    final tZikZak = ZikZakMockData.sampleZikZak;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, ZikZakPatch>(id: tZikZak.id, data: ZikZakPatch()),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, ZikZakPatch>(id: tZikZak.id, data: ZikZakPatch()),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
