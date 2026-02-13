// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'settings.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class Settings extends Params {
  const Settings({Map<String, dynamic>? params}) : super(params: params);

  Settings copyWith({Map<String, dynamic>? params}) {
    return Settings(params: params ?? this.params);
  }

  Settings copyWithSettings({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Settings copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Settings patchWithSettings({SettingsPatch? patchInput}) {
    final _patcher = patchInput ?? SettingsPatch();
    final _patchMap = _patcher.toPatch();
    return Settings(
      params: _patchMap.containsKey(Settings$.params)
          ? (_patchMap[Settings$.params] is Function)
                ? _patchMap[Settings$.params](this.params)
                : _patchMap[Settings$.params]
          : this.params,
    );
  }

  Settings patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return Settings(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : _patchMap[Params$.params]
          : this.params,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings && params == other.params;
  }

  @override
  int get hashCode {
    return Object.hash(params, 0);
  }

  @override
  String toString() {
    return 'Settings(' + 'params: ${params})';
  }

  /// Creates a [Settings] instance from JSON
  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$SettingsToJson(this);
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

extension SettingsSerialization on Settings {
  Map<String, dynamic> toJson() {
    final data = _$SettingsToJson(this);
    data['params'] = params;
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$SettingsToJson(this);
    if (params != null) data['params'] = params;
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

enum Settings$ { params }

class SettingsPatch implements Patch<Settings> {
  final Map<Settings$, dynamic> _patch = {};

  static SettingsPatch create([Map<String, dynamic>? diff]) {
    final patch = SettingsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = Settings$.values.firstWhere((e) => e.name == key);
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

  static SettingsPatch fromPatch(Map<Settings$, dynamic> patch) {
    final _patch = SettingsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<Settings$, dynamic> toPatch() => Map.from(_patch);

  Settings applyTo(Settings entity) {
    return entity.patchWithSettings(patchInput: this);
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

  static SettingsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  SettingsPatch withParams(Map<String, dynamic>? value) {
    _patch[Settings$.params] = value;
    return this;
  }
}

/// Field descriptors for [Settings] query construction
abstract final class SettingsFields {
  static Map<String, dynamic>? _$getparams(Settings e) => e.params;
  static const params = Field<Settings, Map<String, dynamic>?>(
    'params',
    _$getparams,
  );
}

extension SettingsCompareE on Settings {
  Map<String, dynamic> compareToSettings(Settings other) {
    final Map<String, dynamic> diff = {};

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    return diff;
  }
}
