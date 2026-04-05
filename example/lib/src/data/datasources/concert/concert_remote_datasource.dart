import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/concert/concert.dart';
import 'concert_datasource.dart';

class ConcertRemoteDataSource
    with Loggable, FailureHandler
    implements ConcertDataSource {
  @override
  Future<Concert> get(QueryParams<Concert> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<List<Concert>> getList(ListQueryParams<Concert> params) async {
    throw UnimplementedError('Implement remote getList');
  }

  @override
  Stream<Concert> watch(QueryParams<Concert> params) {
    throw UnimplementedError('Implement remote watch');
  }

  @override
  Future<Concert> update(UpdateParams<String, ConcertPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }
}
