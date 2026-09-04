// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'settings.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Settings extends Params {
  const Settings({Map<String, dynamic>? this.params}) : super();

  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  @override
  final Map<String, dynamic>? params;

  Settings copyWith({Map<String, dynamic>? params}) {
    return Settings(params: params ?? this.params);
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Settings copyWithField<T>(Field<Settings, T> field, T value) {
    switch (field.name) {
      case 'params':
        return copyWith(params: value as Map<String, dynamic>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Settings has no settable field with this name',
        );
    }
  }

  Settings copyWithSettings({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  Settings patchWithSettings([SettingsPatch? patchInput]) {
    final _patcher = patchInput ?? SettingsPatch();
    final _patchMap = _patcher.patchMap;
    return Settings(
      params: _patchMap.containsKey(Settings$.params)
          ? ((_patchMap[Settings$.params] is Function)
                    ? _patchMap[Settings$.params](this.params)
                    : (_patchMap[Settings$.params] is Patch)
                    ? _patchMap[Settings$.params].applyTo(this.params)
                    : _patchMap[Settings$.params])
                as Map<String, dynamic>?
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

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$SettingsToJson(this);
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

extension SettingsSerialization on Settings {
  Map<String, dynamic> toJson() {
    return _$SettingsToJson(this);
  }
}

enum Settings$ { params }

class SettingsPatch extends PatchBase<Settings, Settings$> {
  Settings applyTo(Settings entity) {
    return entity.patchWithSettings(this);
  }

  SettingsPatch withParams(Map<String, dynamic>? value) {
    patchMap[Settings$.params] = value;
    return this;
  }
}

/// Field descriptors for [Settings] query construction
abstract final class SettingsFields {
  static const params = Field<Settings, Map<String, dynamic>?>(
    'params',
    _$params,
  );

  static Map<String, dynamic>? _$params(Settings e) {
    return e.params;
  }
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
