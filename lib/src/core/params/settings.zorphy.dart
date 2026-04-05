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
    final _patchMap = _patcher.patchMap;
    return Settings(
      params: _patchMap.containsKey(Settings$.params)
          ? (_patchMap[Settings$.params] is Function)
                ? _patchMap[Settings$.params](this.params)
                : (_patchMap[Settings$.params] is Patch)
                ? _patchMap[Settings$.params].applyTo(this.params)
                : _patchMap[Settings$.params]
          : this.params,
    );
  }

  Settings patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.patchMap;
    return Settings(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : (_patchMap[Params$.params] is Patch)
                ? _patchMap[Params$.params].applyTo(this.params)
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

extension SettingsSerialization on Settings {
  Map<String, dynamic> toJson() => _$SettingsToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$SettingsToJson(this);
    return _sanitizeJson(data);
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

enum Settings$ { params }

class SettingsPatch extends PatchBase<Settings, Settings$> {
  Settings applyTo(Settings entity) {
    return entity.patchWithSettings(patchInput: this);
  }

  SettingsPatch withParams(Map<String, dynamic>? value) {
    patchMap[Settings$.params] = value;
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
