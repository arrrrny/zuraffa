// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/metric_detail/metric_detail_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/metric_detail/metric_detail_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/metric_detail_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_metric_detail_repository.dart';
import 'package:zikzak_demo/src/domain/entities/metric_detail/metric_detail.dart';
import 'package:zikzak_demo/src/domain/repositories/metric_detail_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/metric_detail/update_metric_detail_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingMetricDetailDataSource
    with Loggable, FailureHandler
    implements MetricDetailDataSource {
  @override
  Future<MetricDetail> get(QueryParams<MetricDetail> params) {
    throw (Exception('ThrowingMetricDetailDataSource.get'));
  }

  @override
  Future<List<MetricDetail>> getList(ListQueryParams<MetricDetail> params) {
    throw (Exception('ThrowingMetricDetailDataSource.getList'));
  }

  @override
  Future<MetricDetail> create(MetricDetail entity) {
    throw (Exception('ThrowingMetricDetailDataSource.create'));
  }

  @override
  Future<MetricDetail> update(UpdateParams<String, MetricDetailPatch> params) {
    throw (Exception('ThrowingMetricDetailDataSource.update'));
  }

  @override
  Future<MetricDetail> toggle(
    ToggleParams<String, Field<MetricDetail, dynamic>> params,
  ) {
    throw (Exception('ThrowingMetricDetailDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingMetricDetailDataSource.delete'));
  }

  @override
  Stream<MetricDetail> watch(QueryParams<MetricDetail> params) {
    throw (Exception('ThrowingMetricDetailDataSource.watch'));
  }

  @override
  Stream<List<MetricDetail>> watchList(ListQueryParams<MetricDetail> params) {
    throw (Exception('ThrowingMetricDetailDataSource.watchList'));
  }
}

void main() {
  late UpdateMetricDetailUseCase useCase;
  late UpdateMetricDetailUseCase throwingUseCase;
  late DataMetricDetailRepository repository;
  late DataMetricDetailRepository throwingRepository;
  late MetricDetailMockDataSource mockDataSource;
  late ThrowingMetricDetailDataSource throwingDataSource;
  setUp(() {
    mockDataSource = MetricDetailMockDataSource();
    throwingDataSource = ThrowingMetricDetailDataSource();
    repository = DataMetricDetailRepository(mockDataSource);
    throwingRepository = DataMetricDetailRepository(throwingDataSource);
    useCase = UpdateMetricDetailUseCase(repository);
    throwingUseCase = UpdateMetricDetailUseCase(throwingRepository);
  });
  group('UpdateMetricDetailUseCase', () {
    final tMetricDetail = MetricDetailMockData.sampleMetricDetail;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, MetricDetailPatch>(
          id: tMetricDetail.name,
          data: MetricDetailPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, MetricDetailPatch>(
          id: tMetricDetail.name,
          data: MetricDetailPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
