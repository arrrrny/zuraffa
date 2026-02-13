// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'locale.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Locale {
  @JsonKey()
  final String languageCode;
  final String? countryCode;

  Locale({String? languageCode, this.countryCode})
    : this.languageCode = languageCode ?? 'en';

  Locale copyWith({String? languageCode, String? countryCode}) {
    return Locale(
      languageCode: languageCode ?? this.languageCode,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  Locale copyWithLocale({String? languageCode, String? countryCode}) {
    return copyWith(languageCode: languageCode, countryCode: countryCode);
  }

  Locale patchWithLocale({LocalePatch? patchInput}) {
    final _patcher = patchInput ?? LocalePatch();
    final _patchMap = _patcher.toPatch();
    return Locale(
      languageCode: _patchMap.containsKey(Locale$.languageCode)
          ? (_patchMap[Locale$.languageCode] is Function)
                ? _patchMap[Locale$.languageCode](this.languageCode)
                : _patchMap[Locale$.languageCode]
          : this.languageCode,
      countryCode: _patchMap.containsKey(Locale$.countryCode)
          ? (_patchMap[Locale$.countryCode] is Function)
                ? _patchMap[Locale$.countryCode](this.countryCode)
                : _patchMap[Locale$.countryCode]
          : this.countryCode,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Locale &&
        languageCode == other.languageCode &&
        countryCode == other.countryCode;
  }

  @override
  int get hashCode {
    return Object.hash(this.languageCode, this.countryCode);
  }

  @override
  String toString() {
    return 'Locale(' +
        'languageCode: ${languageCode}' +
        ', ' +
        'countryCode: ${countryCode})';
  }

  /// Creates a [Locale] instance from JSON
  factory Locale.fromJson(Map<String, dynamic> json) => _$LocaleFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$LocaleToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
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
  bool get hasCountryCode => countryCode != null;
  bool get noCountryCode => countryCode == null;
  String get countryCodeRequired =>
      countryCode ?? (throw StateError('countryCode is required but was null'));
}

extension LocaleSerialization on Locale {
  Map<String, dynamic> toJson() => _$LocaleToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$LocaleToJson(this);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

enum Locale$ { languageCode, countryCode }

class LocalePatch implements Patch<Locale> {
  final Map<Locale$, dynamic> _patch = {};

  static LocalePatch create([Map<String, dynamic>? diff]) {
    final patch = LocalePatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Locale$.values.firstWhere((e) => e.name == key);
          if (value is Function) {
            patch._patch[enumValue] = value();
          } else {
            patch._patch[enumValue] = value;
          }
        } catch (_) {}
      });
    }
    return patch;
  }

  static LocalePatch fromPatch(Map<Locale$, dynamic> patch) {
    final _patch = LocalePatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Locale$, dynamic> toPatch() => Map.from(_patch);

  Locale applyTo(Locale entity) {
    return entity.patchWithLocale(patchInput: this);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    _patch.forEach((key, value) {
      if (value != null) {
        if (value is Function) {
          final result = value();
          json[key.name] = _convertToJson(result);
        } else {
          json[key.name] = _convertToJson(value);
        }
      }
    });
    return json;
  }

  dynamic _convertToJson(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Enum) return value.toString().split('.').last;
    if (value is List) return value.map((e) => _convertToJson(e)).toList();
    if (value is Map)
      return value.map((k, v) => MapEntry(k.toString(), _convertToJson(v)));
    if (value is num || value is bool || value is String) return value;
    try {
      if (value?.toJsonLean != null) return value.toJsonLean();
    } catch (_) {}
    if (value?.toJson != null) return value.toJson();
    return value.toString();
  }

  static LocalePatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  LocalePatch withLanguageCode(String? value) {
    _patch[Locale$.languageCode] = value;
    return this;
  }

  LocalePatch withCountryCode(String? value) {
    _patch[Locale$.countryCode] = value;
    return this;
  }
}

extension LocaleCompareE on Locale {
  Map<String, dynamic> compareToLocale(Locale other) {
    final Map<String, dynamic> diff = {};

    if (languageCode != other.languageCode) {
      diff['languageCode'] = () => other.languageCode;
    }
    if (countryCode != other.countryCode) {
      diff['countryCode'] = () => other.countryCode;
    }
    return diff;
  }
}
