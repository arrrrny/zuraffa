import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/concert/concert.dart';

class ConcertState {
  const ConcertState({
    this.error,
    this.concertList = const <Concert>[],
    this.offset = 0,
    this.limit = 10,
    this.hasMore = true,
    this.concert,
    this.isGetting = false,
    this.isGettingList = false,
    this.isWatching = false,
    this.isUpdating = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Concert entity
  final Concert? concert;

  /// The list of Concert entities
  final List<Concert> concertList;

  /// The current offset for pagination
  final int offset;

  /// The maximum number of items to fetch
  final int limit;

  /// Whether more items are available to fetch
  final bool hasMore;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether getList is in progress
  final bool isGettingList;

  /// Whether watch is in progress
  final bool isWatching;

  /// Whether update is in progress
  final bool isUpdating;

  ConcertState copyWith({
    AppFailure? error,
    List<Concert>? concertList,
    int? offset,
    int? limit,
    bool? hasMore,
    Concert? concert,
    bool? isGetting,
    bool? isGettingList,
    bool? isWatching,
    bool? isUpdating,
  }) => ConcertState(
    error: error ?? this.error,
    concertList: concertList ?? this.concertList,
    offset: offset ?? this.offset,
    limit: limit ?? this.limit,
    hasMore: hasMore ?? this.hasMore,
    concert: concert ?? this.concert,
    isGetting: isGetting ?? this.isGetting,
    isGettingList: isGettingList ?? this.isGettingList,
    isWatching: isWatching ?? this.isWatching,
    isUpdating: isUpdating ?? this.isUpdating,
  );

  bool get isLoading => isGetting || isGettingList || isWatching || isUpdating;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConcertState &&
          other.error == error &&
          other.concertList == concertList &&
          other.offset == offset &&
          other.limit == limit &&
          other.hasMore == hasMore &&
          other.concert == concert &&
          other.isGetting == isGetting &&
          other.isGettingList == isGettingList &&
          other.isWatching == isWatching &&
          other.isUpdating == isUpdating;

  @override
  int get hashCode =>
      error.hashCode +
      concertList.hashCode +
      offset.hashCode +
      limit.hashCode +
      hasMore.hashCode +
      concert.hashCode +
      isGetting.hashCode +
      isGettingList.hashCode +
      isWatching.hashCode +
      isUpdating.hashCode;

  @override
  String toString() =>
      'ConcertState(error: $error, concertList: $concertList, offset: $offset, limit: $limit, hasMore: $hasMore, concert: $concert)';
}
