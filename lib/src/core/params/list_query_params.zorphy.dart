// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'list_query_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(
  explicitToJson: true,
  checked: true,
  genericArgumentFactories: true,
)
class ListQueryParams<T> extends Params {
  const ListQueryParams({
    Map<String, dynamic>? this.params,
    String? this.search,
    Filter<T>? this.filter,
    Sort<T>? this.sort,
    int? this.limit,
    int? this.offset,
  }) : super();

  factory ListQueryParams.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) {
    final instance = _$ListQueryParamsFromJson(json, fromJsonT);
    return ListQueryParams(
      params: instance.params,
      search: instance.search,
      filter: json['filter'] != null
          ? FilterConverter.fromJson(json['filter'] as Map<String, dynamic>)
                as Filter<T>?
          : null,
      sort: json['sort'] != null
          ? SortConverter.fromJson(json['sort'] as Map<String, dynamic>)
                as Sort<T>?
          : null,
      limit: instance.limit,
      offset: instance.offset,
    );
  }

  @override
  final Map<String, dynamic>? params;

  final String? search;

  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: FilterConverter.toJson,
    fromJson: FilterConverter.fromJson,
  )
  final Filter<T>? filter;

  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: SortConverter.toJson,
    fromJson: SortConverter.fromJson,
  )
  final Sort<T>? sort;

  final int? limit;

  final int? offset;

  ListQueryParams copyWith({
    Map<String, dynamic>? params,
    String? search,
    Filter<T>? filter,
    Sort<T>? sort,
    int? limit,
    int? offset,
  }) {
    return ListQueryParams(
      params: params ?? this.params,
      search: search ?? this.search,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  ListQueryParams copyWithListQueryParams({
    Map<String, dynamic>? params,
    String? search,
    Filter<T>? filter,
    Sort<T>? sort,
    int? limit,
    int? offset,
  }) {
    return copyWith(
      params: params,
      search: search,
      filter: filter,
      sort: sort,
      limit: limit,
      offset: offset,
    );
  }

  ListQueryParams patchWithListQueryParams([ListQueryParamsPatch? patchInput]) {
    final _patcher = patchInput ?? ListQueryParamsPatch();
    final _patchMap = _patcher.patchMap;
    return ListQueryParams(
      params: _patchMap.containsKey(ListQueryParams$.params)
          ? (_patchMap[ListQueryParams$.params] is Function)
                ? _patchMap[ListQueryParams$.params](this.params)
                : (_patchMap[ListQueryParams$.params] is Patch)
                ? _patchMap[ListQueryParams$.params].applyTo(this.params)
                : _patchMap[ListQueryParams$.params]
          : this.params,
      search: _patchMap.containsKey(ListQueryParams$.search)
          ? (_patchMap[ListQueryParams$.search] is Function)
                ? _patchMap[ListQueryParams$.search](this.search)
                : (_patchMap[ListQueryParams$.search] is Patch)
                ? _patchMap[ListQueryParams$.search].applyTo(this.search)
                : _patchMap[ListQueryParams$.search]
          : this.search,
      filter: _patchMap.containsKey(ListQueryParams$.filter)
          ? (_patchMap[ListQueryParams$.filter] is Function)
                ? _patchMap[ListQueryParams$.filter](this.filter)
                : (_patchMap[ListQueryParams$.filter] is Patch)
                ? _patchMap[ListQueryParams$.filter].applyTo(this.filter)
                : _patchMap[ListQueryParams$.filter]
          : this.filter,
      sort: _patchMap.containsKey(ListQueryParams$.sort)
          ? (_patchMap[ListQueryParams$.sort] is Function)
                ? _patchMap[ListQueryParams$.sort](this.sort)
                : (_patchMap[ListQueryParams$.sort] is Patch)
                ? _patchMap[ListQueryParams$.sort].applyTo(this.sort)
                : _patchMap[ListQueryParams$.sort]
          : this.sort,
      limit: _patchMap.containsKey(ListQueryParams$.limit)
          ? (_patchMap[ListQueryParams$.limit] is Function)
                ? _patchMap[ListQueryParams$.limit](this.limit)
                : (_patchMap[ListQueryParams$.limit] is Patch)
                ? _patchMap[ListQueryParams$.limit].applyTo(this.limit)
                : _patchMap[ListQueryParams$.limit]
          : this.limit,
      offset: _patchMap.containsKey(ListQueryParams$.offset)
          ? (_patchMap[ListQueryParams$.offset] is Function)
                ? _patchMap[ListQueryParams$.offset](this.offset)
                : (_patchMap[ListQueryParams$.offset] is Patch)
                ? _patchMap[ListQueryParams$.offset].applyTo(this.offset)
                : _patchMap[ListQueryParams$.offset]
          : this.offset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ListQueryParams &&
        params == other.params &&
        search == other.search &&
        filter == other.filter &&
        sort == other.sort &&
        limit == other.limit &&
        offset == other.offset;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.params,
      this.search,
      this.filter,
      this.sort,
      this.limit,
      this.offset,
    );
  }

  @override
  String toString() {
    return 'ListQueryParams(' +
        'params: ${params}' +
        ', ' +
        'search: ${search}' +
        ', ' +
        'filter: ${filter}' +
        ', ' +
        'sort: ${sort}' +
        ', ' +
        'limit: ${limit}' +
        ', ' +
        'offset: ${offset})';
  }
}

extension ListQueryParamsPropertyHelpers<T> on ListQueryParams<T> {
  bool get hasSearch {
    return search?.isNotEmpty == true;
  }

  bool get noSearch {
    return search?.isEmpty ?? true;
  }

  String get searchRequired {
    return search ?? (throw StateError('search is required but was null'));
  }

  bool get hasFilter {
    return filter != null;
  }

  bool get noFilter {
    return filter == null;
  }

  Filter<T> get filterRequired {
    return filter ?? (throw StateError('filter is required but was null'));
  }

  bool get hasSort {
    return sort != null;
  }

  bool get noSort {
    return sort == null;
  }

  Sort<T> get sortRequired {
    return sort ?? (throw StateError('sort is required but was null'));
  }

  bool get hasLimit {
    return limit != null;
  }

  bool get noLimit {
    return limit == null;
  }

  int get limitRequired {
    return limit ?? (throw StateError('limit is required but was null'));
  }

  bool get hasOffset {
    return offset != null;
  }

  bool get noOffset {
    return offset == null;
  }

  int get offsetRequired {
    return offset ?? (throw StateError('offset is required but was null'));
  }
}

extension ListQueryParamsSerialization<T> on ListQueryParams<T> {
  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) {
    final data = _$ListQueryParamsToJson(this, toJsonT);
    if (filter != null) data['filter'] = FilterConverter.toJson(filter!);
    if (sort != null) data['sort'] = SortConverter.toJson(sort!);
    return data;
  }
}

enum ListQueryParams$ { params, search, filter, sort, limit, offset }

class ListQueryParamsPatch
    extends PatchBase<ListQueryParams, ListQueryParams$> {
  ListQueryParams applyTo(ListQueryParams entity) {
    return entity.patchWithListQueryParams(this);
  }

  ListQueryParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[ListQueryParams$.params] = value;
    return this;
  }

  ListQueryParamsPatch withSearch(String? value) {
    patchMap[ListQueryParams$.search] = value;
    return this;
  }

  ListQueryParamsPatch withFilter(dynamic value) {
    patchMap[ListQueryParams$.filter] = value;
    return this;
  }

  ListQueryParamsPatch withSort(dynamic value) {
    patchMap[ListQueryParams$.sort] = value;
    return this;
  }

  ListQueryParamsPatch withLimit(int? value) {
    patchMap[ListQueryParams$.limit] = value;
    return this;
  }

  ListQueryParamsPatch withOffset(int? value) {
    patchMap[ListQueryParams$.offset] = value;
    return this;
  }
}

/// Field descriptors for [ListQueryParams] query construction
abstract final class ListQueryParamsFields<T> {
  static Map<String, dynamic>? _$params<T>(ListQueryParams<T> e) {
    return e.params;
  }

  static Field<ListQueryParams<T>, Map<String, dynamic>?> params<T>() {
    return Field<ListQueryParams<T>, Map<String, dynamic>?>(
      'params',
      _$params<T>,
    );
  }

  static String? _$search<T>(ListQueryParams<T> e) {
    return e.search;
  }

  static Field<ListQueryParams<T>, String?> search<T>() {
    return Field<ListQueryParams<T>, String?>('search', _$search<T>);
  }

  static Filter<T>? _$filter<T>(ListQueryParams<T> e) {
    return e.filter;
  }

  static Field<ListQueryParams<T>, Filter<T>?> filter<T>() {
    return Field<ListQueryParams<T>, Filter<T>?>('filter', _$filter<T>);
  }

  static Sort<T>? _$sort<T>(ListQueryParams<T> e) {
    return e.sort;
  }

  static Field<ListQueryParams<T>, Sort<T>?> sort<T>() {
    return Field<ListQueryParams<T>, Sort<T>?>('sort', _$sort<T>);
  }

  static int? _$limit<T>(ListQueryParams<T> e) {
    return e.limit;
  }

  static Field<ListQueryParams<T>, int?> limit<T>() {
    return Field<ListQueryParams<T>, int?>('limit', _$limit<T>);
  }

  static int? _$offset<T>(ListQueryParams<T> e) {
    return e.offset;
  }

  static Field<ListQueryParams<T>, int?> offset<T>() {
    return Field<ListQueryParams<T>, int?>('offset', _$offset<T>);
  }
}

extension ListQueryParamsCompareE on ListQueryParams {
  Map<String, dynamic> compareToListQueryParams(ListQueryParams other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }

    if (search != other.search) {
      diff['search'] = () => other.search;
    }

    if (filter != other.filter) {
      diff['filter'] = () => other.filter;
    }

    if (sort != other.sort) {
      diff['sort'] = () => other.sort;
    }

    if (limit != other.limit) {
      diff['limit'] = () => other.limit;
    }

    if (offset != other.offset) {
      diff['offset'] = () => other.offset;
    }
    return diff;
  }
}
