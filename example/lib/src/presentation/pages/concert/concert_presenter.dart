import 'package:zuraffa/zuraffa.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/concert/concert.dart';
import '../../../domain/usecases/concert/get_concert_list_usecase.dart';
import '../../../domain/usecases/concert/get_concert_usecase.dart';
import '../../../domain/usecases/concert/update_concert_usecase.dart';
import '../../../domain/usecases/concert/watch_concert_usecase.dart';

class ConcertPresenter extends Presenter {
  ConcertPresenter() {
    _getConcert = registerUseCase(getIt<GetConcertUseCase>());
    _getConcertList = registerUseCase(getIt<GetConcertListUseCase>());
    _watchConcert = registerUseCase(getIt<WatchConcertUseCase>());
    _updateConcert = registerUseCase(getIt<UpdateConcertUseCase>());
  }

  late final GetConcertUseCase _getConcert;

  late final GetConcertListUseCase _getConcertList;

  late final WatchConcertUseCase _watchConcert;

  late final UpdateConcertUseCase _updateConcert;

  Future<Result<Concert, AppFailure>> getConcert(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getConcert.call(
      QueryParams<Concert>(filter: Eq(ConcertFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<List<Concert>, AppFailure>> getConcertList([
    ListQueryParams<Concert> params = const ListQueryParams<Concert>(),
    CancelToken? cancelToken,
  ]) {
    return _getConcertList.call(params, cancelToken: cancelToken);
  }

  Stream<Result<Concert, AppFailure>> watchConcert(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _watchConcert.call(
      QueryParams<Concert>(filter: Eq(ConcertFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  (
    Future<Result<Concert, AppFailure>> initial,
    Stream<Result<Concert, AppFailure>> updates,
  )
  watchConcertRecord(String id) {
    return (
      _watchConcert
          .call(QueryParams<Concert>(filter: Eq(ConcertFields.id, id)))
          .first,
      _watchConcert.call(
        QueryParams<Concert>(filter: Eq(ConcertFields.id, id)),
      ),
    );
  }

  Future<Result<Concert, AppFailure>> updateConcert(
    String id,
    ConcertPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateConcert.call(
      UpdateParams<String, ConcertPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }
}
