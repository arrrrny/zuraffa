// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'url_spark.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class UrlSpark {
  UrlSpark({
    String? id,
    required String this.url,
    Map<String, dynamic>? this.metadata,
  }) : this.id = id ?? const Uuid().v4();

  factory UrlSpark.fromJson(Map<String, dynamic> json) =>
      _$UrlSparkFromJson(json);

  final String id;

  final String url;

  final Map<String, dynamic>? metadata;

  UrlSpark copyWith({String? id, String? url, Map<String, dynamic>? metadata}) {
    return UrlSpark(
      id: id ?? this.id,
      url: url ?? this.url,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  UrlSpark copyWithField<T>(Field<UrlSpark, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'url':
        return copyWith(url: value as String);
      case 'metadata':
        return copyWith(metadata: value as Map<String, dynamic>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'UrlSpark has no settable field with this name',
        );
    }
  }

  UrlSpark copyWithUrlSpark({
    String? id,
    String? url,
    Map<String, dynamic>? metadata,
  }) {
    return copyWith(id: id, url: url, metadata: metadata);
  }

  UrlSpark patchWithUrlSpark([UrlSparkPatch? patchInput]) {
    final _patcher = patchInput ?? UrlSparkPatch();
    final _patchMap = _patcher.patchMap;
    return UrlSpark(
      id: _patchMap.containsKey(UrlSpark$.id)
          ? ((_patchMap[UrlSpark$.id] is Function)
                    ? _patchMap[UrlSpark$.id](this.id)
                    : (_patchMap[UrlSpark$.id] is Patch)
                    ? _patchMap[UrlSpark$.id].applyTo(this.id)
                    : _patchMap[UrlSpark$.id])
                as String
          : this.id,
      url: _patchMap.containsKey(UrlSpark$.url)
          ? ((_patchMap[UrlSpark$.url] is Function)
                    ? _patchMap[UrlSpark$.url](this.url)
                    : (_patchMap[UrlSpark$.url] is Patch)
                    ? _patchMap[UrlSpark$.url].applyTo(this.url)
                    : _patchMap[UrlSpark$.url])
                as String
          : this.url,
      metadata: _patchMap.containsKey(UrlSpark$.metadata)
          ? ((_patchMap[UrlSpark$.metadata] is Function)
                    ? _patchMap[UrlSpark$.metadata](this.metadata)
                    : (_patchMap[UrlSpark$.metadata] is Patch)
                    ? _patchMap[UrlSpark$.metadata].applyTo(this.metadata)
                    : _patchMap[UrlSpark$.metadata])
                as Map<String, dynamic>?
          : this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UrlSpark &&
        id == other.id &&
        url == other.url &&
        metadata == other.metadata;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.url, this.metadata);
  }

  @override
  String toString() {
    return 'UrlSpark(' +
        'id: ${id}' +
        ', ' +
        'url: ${url}' +
        ', ' +
        'metadata: ${metadata})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is UrlSpark && url == other.url && metadata == other.metadata;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$UrlSparkToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$UrlSparkToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension UrlSparkPropertyHelpers on UrlSpark {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasUrl {
    return this.url.isNotEmpty;
  }

  bool get noUrl {
    return this.url.isEmpty;
  }

  Map<String, dynamic> get metadataRequired {
    return this.metadata ??
        (throw StateError('metadata is required but was null'));
  }

  bool get hasMetadata {
    return this.metadata?.isNotEmpty ?? false;
  }

  bool get noMetadata {
    return this.metadata?.isEmpty ?? true;
  }
}

extension UrlSparkSerialization on UrlSpark {
  Map<String, dynamic> toJson() {
    return _$UrlSparkToJson(this);
  }
}

enum UrlSpark$ { id, url, metadata }

class UrlSparkPatch extends PatchBase<UrlSpark, UrlSpark$> {
  UrlSpark applyTo(UrlSpark entity) {
    return entity.patchWithUrlSpark(this);
  }

  UrlSparkPatch withId(String? value) {
    patchMap[UrlSpark$.id] = value;
    return this;
  }

  UrlSparkPatch withUrl(String? value) {
    patchMap[UrlSpark$.url] = value;
    return this;
  }

  UrlSparkPatch withMetadata(Map<String, dynamic>? value) {
    patchMap[UrlSpark$.metadata] = value;
    return this;
  }
}

/// Field descriptors for [UrlSpark] query construction
abstract final class UrlSparkFields {
  static const id = Field<UrlSpark, String>('id', _$id);

  static const url = Field<UrlSpark, String>('url', _$url);

  static const metadata = Field<UrlSpark, Map<String, dynamic>?>(
    'metadata',
    _$metadata,
  );

  static String _$id(UrlSpark e) {
    return e.id;
  }

  static String _$url(UrlSpark e) {
    return e.url;
  }

  static Map<String, dynamic>? _$metadata(UrlSpark e) {
    return e.metadata;
  }
}

extension UrlSparkCompareE on UrlSpark {
  Map<String, dynamic> compareToUrlSpark(UrlSpark other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (url != other.url) {
      diff['url'] = () => other.url;
    }

    if (metadata != other.metadata) {
      diff['metadata'] = () => other.metadata;
    }
    return diff;
  }
}
