// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'url_listing.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class UrlListing {
  UrlListing({
    required String this.id,
    required String this.title,
    required String this.url,
  });

  factory UrlListing.fromJson(Map<String, dynamic> json) =>
      _$UrlListingFromJson(json);

  final String id;

  final String title;

  final String url;

  UrlListing copyWith({String? id, String? title, String? url}) {
    return UrlListing(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  UrlListing copyWithField<T>(Field<UrlListing, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'url':
        return copyWith(url: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'UrlListing has no settable field with this name',
        );
    }
  }

  UrlListing copyWithUrlListing({String? id, String? title, String? url}) {
    return copyWith(id: id, title: title, url: url);
  }

  UrlListing patchWithUrlListing([UrlListingPatch? patchInput]) {
    final _patcher = patchInput ?? UrlListingPatch();
    final _patchMap = _patcher.patchMap;
    return UrlListing(
      id: _patchMap.containsKey(UrlListing$.id)
          ? ((_patchMap[UrlListing$.id] is Function)
                    ? _patchMap[UrlListing$.id](this.id)
                    : (_patchMap[UrlListing$.id] is Patch)
                    ? _patchMap[UrlListing$.id].applyTo(this.id)
                    : _patchMap[UrlListing$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(UrlListing$.title)
          ? ((_patchMap[UrlListing$.title] is Function)
                    ? _patchMap[UrlListing$.title](this.title)
                    : (_patchMap[UrlListing$.title] is Patch)
                    ? _patchMap[UrlListing$.title].applyTo(this.title)
                    : _patchMap[UrlListing$.title])
                as String
          : this.title,
      url: _patchMap.containsKey(UrlListing$.url)
          ? ((_patchMap[UrlListing$.url] is Function)
                    ? _patchMap[UrlListing$.url](this.url)
                    : (_patchMap[UrlListing$.url] is Patch)
                    ? _patchMap[UrlListing$.url].applyTo(this.url)
                    : _patchMap[UrlListing$.url])
                as String
          : this.url,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UrlListing &&
        id == other.id &&
        title == other.title &&
        url == other.url;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.title, this.url);
  }

  @override
  String toString() {
    return 'UrlListing(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'url: ${url})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$UrlListingToJson(this);
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

extension UrlListingPropertyHelpers on UrlListing {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasTitle {
    return this.title.isNotEmpty;
  }

  bool get noTitle {
    return this.title.isEmpty;
  }

  bool get hasUrl {
    return this.url.isNotEmpty;
  }

  bool get noUrl {
    return this.url.isEmpty;
  }
}

extension UrlListingSerialization on UrlListing {
  Map<String, dynamic> toJson() {
    return _$UrlListingToJson(this);
  }
}

enum UrlListing$ { id, title, url }

class UrlListingPatch extends PatchBase<UrlListing, UrlListing$> {
  UrlListing applyTo(UrlListing entity) {
    return entity.patchWithUrlListing(this);
  }

  UrlListingPatch withId(String? value) {
    patchMap[UrlListing$.id] = value;
    return this;
  }

  UrlListingPatch withTitle(String? value) {
    patchMap[UrlListing$.title] = value;
    return this;
  }

  UrlListingPatch withUrl(String? value) {
    patchMap[UrlListing$.url] = value;
    return this;
  }
}

/// Field descriptors for [UrlListing] query construction
abstract final class UrlListingFields {
  static const id = Field<UrlListing, String>('id', _$id);

  static const title = Field<UrlListing, String>('title', _$title);

  static const url = Field<UrlListing, String>('url', _$url);

  static String _$id(UrlListing e) {
    return e.id;
  }

  static String _$title(UrlListing e) {
    return e.title;
  }

  static String _$url(UrlListing e) {
    return e.url;
  }
}

extension UrlListingCompareE on UrlListing {
  Map<String, dynamic> compareToUrlListing(UrlListing other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (url != other.url) {
      diff['url'] = () => other.url;
    }
    return diff;
  }
}
