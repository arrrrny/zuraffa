// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/device_info/device_info_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/device_info/device_info_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/device_info_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_device_info_repository.dart';
import 'package:zikzak_demo/src/domain/entities/device_info/device_info.dart';
import 'package:zikzak_demo/src/domain/repositories/device_info_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/device_info/update_device_info_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingDeviceInfoDataSource
    with Loggable, FailureHandler
    implements DeviceInfoDataSource {
  @override
  Future<DeviceInfo> get(QueryParams<DeviceInfo> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.get'));
  }

  @override
  Future<List<DeviceInfo>> getList(ListQueryParams<DeviceInfo> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.getList'));
  }

  @override
  Future<DeviceInfo> create(DeviceInfo entity) {
    throw (Exception('ThrowingDeviceInfoDataSource.create'));
  }

  @override
  Future<DeviceInfo> update(UpdateParams<String, DeviceInfoPatch> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.update'));
  }

  @override
  Future<DeviceInfo> toggle(
    ToggleParams<String, Field<DeviceInfo, dynamic>> params,
  ) {
    throw (Exception('ThrowingDeviceInfoDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.delete'));
  }

  @override
  Stream<DeviceInfo> watch(QueryParams<DeviceInfo> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.watch'));
  }

  @override
  Stream<List<DeviceInfo>> watchList(ListQueryParams<DeviceInfo> params) {
    throw (Exception('ThrowingDeviceInfoDataSource.watchList'));
  }
}

void main() {
  late UpdateDeviceInfoUseCase useCase;
  late UpdateDeviceInfoUseCase throwingUseCase;
  late DataDeviceInfoRepository repository;
  late DataDeviceInfoRepository throwingRepository;
  late DeviceInfoMockDataSource mockDataSource;
  late ThrowingDeviceInfoDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DeviceInfoMockDataSource();
    throwingDataSource = ThrowingDeviceInfoDataSource();
    repository = DataDeviceInfoRepository(mockDataSource);
    throwingRepository = DataDeviceInfoRepository(throwingDataSource);
    useCase = UpdateDeviceInfoUseCase(repository);
    throwingUseCase = UpdateDeviceInfoUseCase(throwingRepository);
  });
  group('UpdateDeviceInfoUseCase', () {
    final tDeviceInfo = DeviceInfoMockData.sampleDeviceInfo;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, DeviceInfoPatch>(
          id: tDeviceInfo.deviceId,
          data: DeviceInfoPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, DeviceInfoPatch>(
          id: tDeviceInfo.deviceId,
          data: DeviceInfoPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
