// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/device/device_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/device/device_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/device_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_device_repository.dart';
import 'package:zikzak_demo/src/domain/entities/device/device.dart';
import 'package:zikzak_demo/src/domain/repositories/device_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/device/toggle_device_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingDeviceDataSource
    with Loggable, FailureHandler
    implements DeviceDataSource {
  @override
  Future<Device> get(QueryParams<Device> params) {
    throw (Exception('ThrowingDeviceDataSource.get'));
  }

  @override
  Future<List<Device>> getList(ListQueryParams<Device> params) {
    throw (Exception('ThrowingDeviceDataSource.getList'));
  }

  @override
  Future<Device> create(Device entity) {
    throw (Exception('ThrowingDeviceDataSource.create'));
  }

  @override
  Future<Device> update(UpdateParams<String, DevicePatch> params) {
    throw (Exception('ThrowingDeviceDataSource.update'));
  }

  @override
  Future<Device> toggle(ToggleParams<String, Field<Device, dynamic>> params) {
    throw (Exception('ThrowingDeviceDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingDeviceDataSource.delete'));
  }

  @override
  Stream<Device> watch(QueryParams<Device> params) {
    throw (Exception('ThrowingDeviceDataSource.watch'));
  }

  @override
  Stream<List<Device>> watchList(ListQueryParams<Device> params) {
    throw (Exception('ThrowingDeviceDataSource.watchList'));
  }
}

void main() {
  late ToggleDeviceUseCase useCase;
  late ToggleDeviceUseCase throwingUseCase;
  late DataDeviceRepository repository;
  late DataDeviceRepository throwingRepository;
  late DeviceMockDataSource mockDataSource;
  late ThrowingDeviceDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DeviceMockDataSource();
    throwingDataSource = ThrowingDeviceDataSource();
    repository = DataDeviceRepository(mockDataSource);
    throwingRepository = DataDeviceRepository(throwingDataSource);
    useCase = ToggleDeviceUseCase(repository);
    throwingUseCase = ToggleDeviceUseCase(throwingRepository);
  });
  group('ToggleDeviceUseCase', () {
    final tDevice = DeviceMockData.sampleDevice;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Device, dynamic>>(
          id: tDevice.id,
          field: DeviceFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Device, dynamic>>(
          id: tDevice.id,
          field: DeviceFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
