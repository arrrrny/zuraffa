import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/concert/concert.dart';

abstract class ConcertDataSource with Loggable, FailureHandler {
  Future<Concert> get(QueryParams<Concert> params);
  Future<List<Concert>> getList(ListQueryParams<Concert> params);
  Stream<Concert> watch(QueryParams<Concert> params);
  Future<Concert> update(UpdateParams<String, ConcertPatch> params);
}
