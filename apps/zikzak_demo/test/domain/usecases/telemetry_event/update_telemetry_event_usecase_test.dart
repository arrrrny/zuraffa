// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/telemetry_event/telemetry_event_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/telemetry_event/telemetry_event_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/telemetry_event_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_telemetry_event_repository.dart';
import 'package:zikzak_demo/src/domain/entities/telemetry_event/telemetry_event.dart';
import 'package:zikzak_demo/src/domain/repositories/telemetry_event_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/telemetry_event/update_telemetry_event_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingTelemetryEventDataSource
    with Loggable, FailureHandler
    implements TelemetryEventDataSource {
  @override
  Future<TelemetryEvent> get(QueryParams<TelemetryEvent> params) {
    throw (Exception('ThrowingTelemetryEventDataSource.get'));
  }

  @override
  Future<List<TelemetryEvent>> getList(ListQueryParams<TelemetryEvent> params) {
    throw (Exception('ThrowingTelemetryEventDataSource.getList'));
  }

  @override
  Future<TelemetryEvent> create(TelemetryEvent entity) {
    throw (Exception('ThrowingTelemetryEventDataSource.create'));
  }

  @override
  Future<TelemetryEvent> update(
    UpdateParams<String, TelemetryEventPatch> params,
  ) {
    throw (Exception('ThrowingTelemetryEventDataSource.update'));
  }

  @override
  Future<TelemetryEvent> toggle(
    ToggleParams<String, Field<TelemetryEvent, dynamic>> params,
  ) {
    throw (Exception('ThrowingTelemetryEventDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingTelemetryEventDataSource.delete'));
  }

  @override
  Stream<TelemetryEvent> watch(QueryParams<TelemetryEvent> params) {
    throw (Exception('ThrowingTelemetryEventDataSource.watch'));
  }

  @override
  Stream<List<TelemetryEvent>> watchList(
    ListQueryParams<TelemetryEvent> params,
  ) {
    throw (Exception('ThrowingTelemetryEventDataSource.watchList'));
  }
}

void main() {
  late UpdateTelemetryEventUseCase useCase;
  late UpdateTelemetryEventUseCase throwingUseCase;
  late DataTelemetryEventRepository repository;
  late DataTelemetryEventRepository throwingRepository;
  late TelemetryEventMockDataSource mockDataSource;
  late ThrowingTelemetryEventDataSource throwingDataSource;
  setUp(() {
    mockDataSource = TelemetryEventMockDataSource();
    throwingDataSource = ThrowingTelemetryEventDataSource();
    repository = DataTelemetryEventRepository(mockDataSource);
    throwingRepository = DataTelemetryEventRepository(throwingDataSource);
    useCase = UpdateTelemetryEventUseCase(repository);
    throwingUseCase = UpdateTelemetryEventUseCase(throwingRepository);
  });
  group('UpdateTelemetryEventUseCase', () {
    final tTelemetryEvent = TelemetryEventMockData.sampleTelemetryEvent;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, TelemetryEventPatch>(
          id: tTelemetryEvent.id,
          data: TelemetryEventPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, TelemetryEventPatch>(
          id: tTelemetryEvent.id,
          data: TelemetryEventPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
