import 'package:example/src/domain/entities/concert/concert.dart';
import 'package:zuraffa/zuraffa.dart';

import 'concert_presenter.dart';
import 'concert_state.dart';

class ConcertController extends Controller
    with StatefulController<ConcertState> {
  ConcertController(this._presenter, {this.initialConcert});

  final ConcertPresenter _presenter;

  final Concert? initialConcert;

  @override
  ConcertState createInitialState() {
    return ConcertState(concert: initialConcert);
  }

  Future<void> getConcert(String id, [CancelToken? cancelToken]) async {
    updateState(viewState.copyWith(isGetting: true));
    final result = await _presenter.getConcert(id, cancelToken);
    result.fold(
      (entity) {
        updateState(viewState.copyWith(isGetting: false, concert: entity));
      },
      (failure) {
        updateState(viewState.copyWith(isGetting: false, error: failure));
      },
    );
  }

  Future<void> getConcertList([
    bool refresh = false,
    ListQueryParams<Concert> params = const ListQueryParams<Concert>(),
    CancelToken? cancelToken,
  ]) async {
    updateState(viewState.copyWith(isGettingList: true, concertList: []));
    final result = await _presenter.getConcertList(params, cancelToken);
    result.fold(
      (list) {
        updateState(
          viewState.copyWith(isGettingList: false, concertList: list),
        );
      },
      (failure) {
        updateState(viewState.copyWith(isGettingList: false, error: failure));
      },
    );
  }

  void watchConcert(String id, [CancelToken? cancelToken]) {
    updateState(viewState.copyWith(isWatching: true));
    final subscription = _presenter.watchConcert(id, cancelToken).listen((
      result,
    ) {
      result.fold(
        (entity) {
          updateState(viewState.copyWith(isWatching: false, concert: entity));
        },
        (failure) {
          updateState(viewState.copyWith(isWatching: false, error: failure));
        },
      );
    });
    registerSubscription(subscription);
  }

  Future<void> watchConcertRecord(String id, [CancelToken? cancelToken]) async {
    updateState(viewState.copyWith(isWatching: true));
    final (initialFuture, updatesStream) = _presenter.watchConcertRecord(id);
    () async {
      final result = await initialFuture;
      result.fold(
        (entity) {
          updateState(viewState.copyWith(isWatching: false, concert: entity));
        },
        (failure) {
          updateState(viewState.copyWith(isWatching: false, error: failure));
        },
      );
    }();
    final subscription = updatesStream.listen((result) {
      result.fold(
        (entity) {
          updateState(viewState.copyWith(concert: entity));
        },
        (failure) {
          updateState(viewState.copyWith(error: failure));
        },
      );
    });
    registerSubscription(subscription);
  }

  Future<void> updateConcert(
    String id,
    ConcertPatch data, [
    CancelToken? cancelToken,
  ]) async {
    updateState(viewState.copyWith(isUpdating: true));
    final result = await _presenter.updateConcert(id, data, cancelToken);
    result.fold(
      (updated) {
        updateState(
          viewState.copyWith(
            isUpdating: false,
            concert: viewState.concert?.id == updated.id
                ? updated
                : viewState.concert,
            concertList: viewState.concertList
                .map((e) => e.id == updated.id ? updated : e)
                .toList(),
          ),
        );
      },
      (failure) {
        updateState(viewState.copyWith(isUpdating: false, error: failure));
      },
    );
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
