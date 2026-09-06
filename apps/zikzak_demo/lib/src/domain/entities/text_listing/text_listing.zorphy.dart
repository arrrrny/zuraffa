// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'text_listing.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class TextListing {
  TextListing({
    required String this.id,
    required String this.title,
    required String this.search,
  });

  factory TextListing.fromJson(Map<String, dynamic> json) =>
      _$TextListingFromJson(json);

  final String id;

  final String title;

  final String search;

  TextListing copyWith({String? id, String? title, String? search}) {
    return TextListing(
      id: id ?? this.id,
      title: title ?? this.title,
      search: search ?? this.search,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  TextListing copyWithField<T>(Field<TextListing, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'search':
        return copyWith(search: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'TextListing has no settable field with this name',
        );
    }
  }

  TextListing copyWithTextListing({String? id, String? title, String? search}) {
    return copyWith(id: id, title: title, search: search);
  }

  TextListing patchWithTextListing([TextListingPatch? patchInput]) {
    final _patcher = patchInput ?? TextListingPatch();
    final _patchMap = _patcher.patchMap;
    return TextListing(
      id: _patchMap.containsKey(TextListing$.id)
          ? ((_patchMap[TextListing$.id] is Function)
                    ? _patchMap[TextListing$.id](this.id)
                    : (_patchMap[TextListing$.id] is Patch)
                    ? _patchMap[TextListing$.id].applyTo(this.id)
                    : _patchMap[TextListing$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(TextListing$.title)
          ? ((_patchMap[TextListing$.title] is Function)
                    ? _patchMap[TextListing$.title](this.title)
                    : (_patchMap[TextListing$.title] is Patch)
                    ? _patchMap[TextListing$.title].applyTo(this.title)
                    : _patchMap[TextListing$.title])
                as String
          : this.title,
      search: _patchMap.containsKey(TextListing$.search)
          ? ((_patchMap[TextListing$.search] is Function)
                    ? _patchMap[TextListing$.search](this.search)
                    : (_patchMap[TextListing$.search] is Patch)
                    ? _patchMap[TextListing$.search].applyTo(this.search)
                    : _patchMap[TextListing$.search])
                as String
          : this.search,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextListing &&
        id == other.id &&
        title == other.title &&
        search == other.search;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.title, this.search);
  }

  @override
  String toString() {
    return 'TextListing(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'search: ${search})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TextListingToJson(this);
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

extension TextListingPropertyHelpers on TextListing {
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

  bool get hasSearch {
    return this.search.isNotEmpty;
  }

  bool get noSearch {
    return this.search.isEmpty;
  }
}

extension TextListingSerialization on TextListing {
  Map<String, dynamic> toJson() {
    return _$TextListingToJson(this);
  }
}

enum TextListing$ { id, title, search }

class TextListingPatch extends PatchBase<TextListing, TextListing$> {
  TextListing applyTo(TextListing entity) {
    return entity.patchWithTextListing(this);
  }

  TextListingPatch withId(String? value) {
    patchMap[TextListing$.id] = value;
    return this;
  }

  TextListingPatch withTitle(String? value) {
    patchMap[TextListing$.title] = value;
    return this;
  }

  TextListingPatch withSearch(String? value) {
    patchMap[TextListing$.search] = value;
    return this;
  }
}

/// Field descriptors for [TextListing] query construction
abstract final class TextListingFields {
  static const id = Field<TextListing, String>('id', _$id);

  static const title = Field<TextListing, String>('title', _$title);

  static const search = Field<TextListing, String>('search', _$search);

  static String _$id(TextListing e) {
    return e.id;
  }

  static String _$title(TextListing e) {
    return e.title;
  }

  static String _$search(TextListing e) {
    return e.search;
  }
}

extension TextListingCompareE on TextListing {
  Map<String, dynamic> compareToTextListing(TextListing other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (search != other.search) {
      diff['search'] = () => other.search;
    }
    return diff;
  }
}
