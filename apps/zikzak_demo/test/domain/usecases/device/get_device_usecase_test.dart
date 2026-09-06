// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/device/device_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/device/device_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/device_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_device_repository.dart';
import 'package:zikzak_demo/src/domain/entities/device/device.dart';
import 'package:zikzak_demo/src/domain/repositories/device_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/device/get_device_usecase.dart';
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
  late GetDeviceUseCase useCase;
  late GetDeviceUseCase throwingUseCase;
  late DataDeviceRepository repository;
  late DataDeviceRepository throwingRepository;
  late DeviceMockDataSource mockDataSource;
  late ThrowingDeviceDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DeviceMockDataSource();
    throwingDataSource = ThrowingDeviceDataSource();
    repository = DataDeviceRepository(mockDataSource);
    throwingRepository = DataDeviceRepository(throwingDataSource);
    useCase = GetDeviceUseCase(repository);
    throwingUseCase = GetDeviceUseCase(throwingRepository);
  });
  group('GetDeviceUseCase', () {
    final tDevice = DeviceMockData.sampleDevice;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<Device>(filter: Eq(DeviceFields.id, tDevice.id)),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tDevice),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<Device>(filter: Eq(DeviceFields.id, tDevice.id)),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
