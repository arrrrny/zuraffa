part of 'list_query_params.dart';

// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class ListQueryParams<T> implements ZorphyValueBase {
  ListQueryParams.fromTrusted({
    this.search,
    this.filter,
    this.sort,
    this.limit,
    this.offset,
    Map<String, dynamic>? params,
  }) : params = params == null ? null : Map<String, dynamic>.of(params);

  final String? search;

  final ZorphyFilter<T>? filter;

  final ZorphySort<T>? sort;

  final int? limit;

  final int? offset;

  final Map<String, dynamic>? params;

  ListQueryParams<T> copyWith({
    Object? search = _sentinel,
    Object? filter = _sentinel,
    Object? sort = _sentinel,
    Object? limit = _sentinel,
    Object? offset = _sentinel,
    Object? params = _sentinel,
  }) {
    return ListQueryParams<T>.fromTrusted(
      search: identical(search, _sentinel) ? this.search : search as String?,
      filter: identical(filter, _sentinel)
          ? this.filter
          : filter as ZorphyFilter<T>?,
      sort: identical(sort, _sentinel) ? this.sort : sort as ZorphySort<T>?,
      limit: identical(limit, _sentinel) ? this.limit : limit as int?,
      offset: identical(offset, _sentinel) ? this.offset : offset as int?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListQueryParams &&
        this.search == other.search &&
        this.filter == other.filter &&
        this.sort == other.sort &&
        this.limit == other.limit &&
        this.offset == other.offset &&
        ListQueryParams._zorphyCollectionEquals(this.params, other.params);
  }

  @override
  int get hashCode => Object.hashAll([
    search,
    filter,
    sort,
    limit,
    offset,
    ListQueryParams._zorphyCollectionHash(params),
  ]);

  @override
  String toString() =>
      'ListQueryParams(search: $search, filter: $filter, sort: $sort, limit: $limit, offset: $offset, params: $params)';

  static bool _zorphyCollectionEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every(b.contains);
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static int _zorphyCollectionHash(Object? value) {
    if (value is List) return Object.hashAll(value);
    if (value is Set) {
      return value.fold<int>(0, (hash, element) => hash + element.hashCode);
    }
    if (value is Map) {
      return value.entries.fold<int>(
        0,
        (hash, entry) => hash + Object.hash(entry.key, entry.value),
      );
    }
    return value.hashCode;
  }

  static ZorphyBoundaryResult<ListQueryParams<T>> fromWire<T>(
    Map<String, Object?> raw,
    ZorphyBoundaryResult<T> Function(Map<String, Object?> raw) decodeT,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_search = raw['search'];
    String? _search;
    if (raw_search != null) {
      _search = _boundaryAs<String>(raw_search, '/search', violations);
    }
    final Object? raw_filter = raw['filter'];
    ZorphyFilter<T>? _filter;
    if (raw_filter != null) {
      _filter = _boundaryAs<ZorphyFilter<T>>(raw_filter, '/filter', violations);
    }
    final Object? raw_sort = raw['sort'];
    ZorphySort<T>? _sort;
    if (raw_sort != null) {
      _sort = _boundaryAs<ZorphySort<T>>(raw_sort, '/sort', violations);
    }
    final Object? raw_limit = raw['limit'];
    int? _limit;
    if (raw_limit != null) {
      _limit = _boundaryAs<int>(raw_limit, '/limit', violations);
    }
    final Object? raw_offset = raw['offset'];
    int? _offset;
    if (raw_offset != null) {
      _offset = _boundaryAs<int>(raw_offset, '/offset', violations);
    }
    final Object? raw_params = raw['params'];
    Map<String, dynamic>? _params;
    if (raw_params != null) {
      final map_params = _boundaryObject(raw_params, '/params', violations);
      if (map_params != null) {
        final decoded_params = <String, dynamic>{};
        for (final entry in map_params.entries) {
          final path_params = '/params' + '/' + entry.key;
          if (map_params[entry.key] == null) {
            decoded_params[entry.key] = null;
          } else {
            final element_params = _boundaryAs<dynamic>(
              map_params[entry.key],
              path_params,
              violations,
            );
            if (element_params != null) {
              decoded_params[entry.key] = element_params;
            }
          }
        }
        _params = decoded_params;
      }
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<ListQueryParams<T>>(
        targetType: 'ListQueryParams',
        violations: violations,
      );
    }
    return BoundaryOk<ListQueryParams<T>>(
      ListQueryParams.fromTrusted(
        search: _search,
        filter: _filter,
        sort: _sort,
        limit: _limit,
        offset: _offset,
        params: _params,
      ),
    );
  }

  Map<String, Object?> toWire(Map<String, Object?> Function(T value) encodeT) {
    final map = <String, Object?>{};
    final _search = this.search;
    if (_search != null) {
      map['search'] = _search;
    }
    final _filter = this.filter;
    if (_filter != null) {
      map['filter'] = _filter;
    }
    final _sort = this.sort;
    if (_sort != null) {
      map['sort'] = _sort;
    }
    final _limit = this.limit;
    if (_limit != null) {
      map['limit'] = _limit;
    }
    final _offset = this.offset;
    if (_offset != null) {
      map['offset'] = _offset;
    }
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
}

T? _boundaryAs<T>(Object? value, String path, List<FieldViolation> violations) {
  if (value is T) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: '$T',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

Map<String, Object?>? _boundaryObject(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is Map<String, Object?>) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: 'Map<String, Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}
