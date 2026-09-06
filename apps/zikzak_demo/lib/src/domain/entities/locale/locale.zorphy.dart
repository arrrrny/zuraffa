// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'locale.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Locale {
  Locale({
    required String this.id,
    required String this.languageCode,
    required String this.countryCode,
  });

  factory Locale.fromJson(Map<String, dynamic> json) => _$LocaleFromJson(json);

  final String id;

  final String languageCode;

  final String countryCode;

  Locale copyWith({String? id, String? languageCode, String? countryCode}) {
    return Locale(
      id: id ?? this.id,
      languageCode: languageCode ?? this.languageCode,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Locale copyWithField<T>(Field<Locale, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'languageCode':
        return copyWith(languageCode: value as String);
      case 'countryCode':
        return copyWith(countryCode: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Locale has no settable field with this name',
        );
    }
  }

  Locale copyWithLocale({
    String? id,
    String? languageCode,
    String? countryCode,
  }) {
    return copyWith(
      id: id,
      languageCode: languageCode,
      countryCode: countryCode,
    );
  }

  Locale patchWithLocale([LocalePatch? patchInput]) {
    final _patcher = patchInput ?? LocalePatch();
    final _patchMap = _patcher.patchMap;
    return Locale(
      id: _patchMap.containsKey(Locale$.id)
          ? ((_patchMap[Locale$.id] is Function)
                    ? _patchMap[Locale$.id](this.id)
                    : (_patchMap[Locale$.id] is Patch)
                    ? _patchMap[Locale$.id].applyTo(this.id)
                    : _patchMap[Locale$.id])
                as String
          : this.id,
      languageCode: _patchMap.containsKey(Locale$.languageCode)
          ? ((_patchMap[Locale$.languageCode] is Function)
                    ? _patchMap[Locale$.languageCode](this.languageCode)
                    : (_patchMap[Locale$.languageCode] is Patch)
                    ? _patchMap[Locale$.languageCode].applyTo(this.languageCode)
                    : _patchMap[Locale$.languageCode])
                as String
          : this.languageCode,
      countryCode: _patchMap.containsKey(Locale$.countryCode)
          ? ((_patchMap[Locale$.countryCode] is Function)
                    ? _patchMap[Locale$.countryCode](this.countryCode)
                    : (_patchMap[Locale$.countryCode] is Patch)
                    ? _patchMap[Locale$.countryCode].applyTo(this.countryCode)
                    : _patchMap[Locale$.countryCode])
                as String
          : this.countryCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Locale &&
        id == other.id &&
        languageCode == other.languageCode &&
        countryCode == other.countryCode;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.languageCode, this.countryCode);
  }

  @override
  String toString() {
    return 'Locale(' +
        'id: ${id}' +
        ', ' +
        'languageCode: ${languageCode}' +
        ', ' +
        'countryCode: ${countryCode})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$LocaleToJson(this);
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

extension LocalePropertyHelpers on Locale {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasLanguageCode {
    return this.languageCode.isNotEmpty;
  }

  bool get noLanguageCode {
    return this.languageCode.isEmpty;
  }

  bool get hasCountryCode {
    return this.countryCode.isNotEmpty;
  }

  bool get noCountryCode {
    return this.countryCode.isEmpty;
  }
}

extension LocaleSerialization on Locale {
  Map<String, dynamic> toJson() {
    return _$LocaleToJson(this);
  }
}

enum Locale$ { id, languageCode, countryCode }

class LocalePatch extends PatchBase<Locale, Locale$> {
  Locale applyTo(Locale entity) {
    return entity.patchWithLocale(this);
  }

  LocalePatch withId(String? value) {
    patchMap[Locale$.id] = value;
    return this;
  }

  LocalePatch withLanguageCode(String? value) {
    patchMap[Locale$.languageCode] = value;
    return this;
  }

  LocalePatch withCountryCode(String? value) {
    patchMap[Locale$.countryCode] = value;
    return this;
  }
}

/// Field descriptors for [Locale] query construction
abstract final class LocaleFields {
  static const id = Field<Locale, String>('id', _$id);

  static const languageCode = Field<Locale, String>(
    'languageCode',
    _$languageCode,
  );

  static const countryCode = Field<Locale, String>(
    'countryCode',
    _$countryCode,
  );

  static String _$id(Locale e) {
    return e.id;
  }

  static String _$languageCode(Locale e) {
    return e.languageCode;
  }

  static String _$countryCode(Locale e) {
    return e.countryCode;
  }
}

extension LocaleCompareE on Locale {
  Map<String, dynamic> compareToLocale(Locale other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (languageCode != other.languageCode) {
      diff['languageCode'] = () => other.languageCode;
    }

    if (countryCode != other.countryCode) {
      diff['countryCode'] = () => other.countryCode;
    }
    return diff;
  }
}
