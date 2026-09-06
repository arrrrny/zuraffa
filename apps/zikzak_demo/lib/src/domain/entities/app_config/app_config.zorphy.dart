// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'app_config.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class AppConfig {
  AppConfig({
    String? id,
    required String this.key,
    String? this.value,
    String? this.description,
    required bool this.enabled,
    DateTime? this.updatedAt,
  }) : this.id = id ?? const Uuid().v4();

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  final String id;

  final String key;

  final String? value;

  final String? description;

  final bool enabled;

  final DateTime? updatedAt;

  AppConfig copyWith({
    String? id,
    String? key,
    String? value,
    String? description,
    bool? enabled,
    DateTime? updatedAt,
  }) {
    return AppConfig(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  AppConfig copyWithField<T>(Field<AppConfig, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'key':
        return copyWith(key: value as String);
      case 'value':
        return copyWith(value: value as String?);
      case 'description':
        return copyWith(description: value as String?);
      case 'enabled':
        return copyWith(enabled: value as bool);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'AppConfig has no settable field with this name',
        );
    }
  }

  AppConfig copyWithAppConfig({
    String? id,
    String? key,
    String? value,
    String? description,
    bool? enabled,
    DateTime? updatedAt,
  }) {
    return copyWith(
      id: id,
      key: key,
      value: value,
      description: description,
      enabled: enabled,
      updatedAt: updatedAt,
    );
  }

  AppConfig patchWithAppConfig([AppConfigPatch? patchInput]) {
    final _patcher = patchInput ?? AppConfigPatch();
    final _patchMap = _patcher.patchMap;
    return AppConfig(
      id: _patchMap.containsKey(AppConfig$.id)
          ? ((_patchMap[AppConfig$.id] is Function)
                    ? _patchMap[AppConfig$.id](this.id)
                    : (_patchMap[AppConfig$.id] is Patch)
                    ? _patchMap[AppConfig$.id].applyTo(this.id)
                    : _patchMap[AppConfig$.id])
                as String
          : this.id,
      key: _patchMap.containsKey(AppConfig$.key)
          ? ((_patchMap[AppConfig$.key] is Function)
                    ? _patchMap[AppConfig$.key](this.key)
                    : (_patchMap[AppConfig$.key] is Patch)
                    ? _patchMap[AppConfig$.key].applyTo(this.key)
                    : _patchMap[AppConfig$.key])
                as String
          : this.key,
      value: _patchMap.containsKey(AppConfig$.value)
          ? ((_patchMap[AppConfig$.value] is Function)
                    ? _patchMap[AppConfig$.value](this.value)
                    : (_patchMap[AppConfig$.value] is Patch)
                    ? _patchMap[AppConfig$.value].applyTo(this.value)
                    : _patchMap[AppConfig$.value])
                as String?
          : this.value,
      description: _patchMap.containsKey(AppConfig$.description)
          ? ((_patchMap[AppConfig$.description] is Function)
                    ? _patchMap[AppConfig$.description](this.description)
                    : (_patchMap[AppConfig$.description] is Patch)
                    ? _patchMap[AppConfig$.description].applyTo(
                        this.description,
                      )
                    : _patchMap[AppConfig$.description])
                as String?
          : this.description,
      enabled: _patchMap.containsKey(AppConfig$.enabled)
          ? ((_patchMap[AppConfig$.enabled] is Function)
                    ? _patchMap[AppConfig$.enabled](this.enabled)
                    : (_patchMap[AppConfig$.enabled] is Patch)
                    ? _patchMap[AppConfig$.enabled].applyTo(this.enabled)
                    : _patchMap[AppConfig$.enabled])
                as bool
          : this.enabled,
      updatedAt: _patchMap.containsKey(AppConfig$.updatedAt)
          ? ((_patchMap[AppConfig$.updatedAt] is Function)
                    ? _patchMap[AppConfig$.updatedAt](this.updatedAt)
                    : (_patchMap[AppConfig$.updatedAt] is Patch)
                    ? _patchMap[AppConfig$.updatedAt].applyTo(this.updatedAt)
                    : _patchMap[AppConfig$.updatedAt])
                as DateTime?
          : this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        id == other.id &&
        key == other.key &&
        value == other.value &&
        description == other.description &&
        enabled == other.enabled &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.key,
      this.value,
      this.description,
      this.enabled,
      this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AppConfig(' +
        'id: ${id}' +
        ', ' +
        'key: ${key}' +
        ', ' +
        'value: ${value}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'enabled: ${enabled}' +
        ', ' +
        'updatedAt: ${updatedAt})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        key == other.key &&
        value == other.value &&
        description == other.description &&
        enabled == other.enabled &&
        updatedAt == other.updatedAt;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$AppConfigToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$AppConfigToJson(this);
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

extension AppConfigPropertyHelpers on AppConfig {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasKey {
    return this.key.isNotEmpty;
  }

  bool get noKey {
    return this.key.isEmpty;
  }

  bool get hasValue {
    return this.value?.isNotEmpty == true;
  }

  bool get noValue {
    return this.value?.isEmpty ?? true;
  }

  String get valueRequired {
    return this.value ?? (throw StateError('value is required but was null'));
  }

  bool get hasDescription {
    return this.description?.isNotEmpty == true;
  }

  bool get noDescription {
    return this.description?.isEmpty ?? true;
  }

  String get descriptionRequired {
    return this.description ??
        (throw StateError('description is required but was null'));
  }

  bool get hasUpdatedAt {
    return this.updatedAt != null;
  }

  bool get noUpdatedAt {
    return this.updatedAt == null;
  }

  DateTime get updatedAtRequired {
    return this.updatedAt ??
        (throw StateError('updatedAt is required but was null'));
  }
}

extension AppConfigSerialization on AppConfig {
  Map<String, dynamic> toJson() {
    return _$AppConfigToJson(this);
  }
}

enum AppConfig$ { id, key, value, description, enabled, updatedAt }

class AppConfigPatch extends PatchBase<AppConfig, AppConfig$> {
  AppConfig applyTo(AppConfig entity) {
    return entity.patchWithAppConfig(this);
  }

  AppConfigPatch withId(String? value) {
    patchMap[AppConfig$.id] = value;
    return this;
  }

  AppConfigPatch withKey(String? value) {
    patchMap[AppConfig$.key] = value;
    return this;
  }

  AppConfigPatch withValue(String? value) {
    patchMap[AppConfig$.value] = value;
    return this;
  }

  AppConfigPatch withDescription(String? value) {
    patchMap[AppConfig$.description] = value;
    return this;
  }

  AppConfigPatch withEnabled(bool? value) {
    patchMap[AppConfig$.enabled] = value;
    return this;
  }

  AppConfigPatch withUpdatedAt(DateTime? value) {
    patchMap[AppConfig$.updatedAt] = value;
    return this;
  }
}

/// Field descriptors for [AppConfig] query construction
abstract final class AppConfigFields {
  static const id = Field<AppConfig, String>('id', _$id);

  static const key = Field<AppConfig, String>('key', _$key);

  static const value = Field<AppConfig, String?>('value', _$value);

  static const description = Field<AppConfig, String?>(
    'description',
    _$description,
  );

  static const enabled = Field<AppConfig, bool>('enabled', _$enabled);

  static const updatedAt = Field<AppConfig, DateTime?>(
    'updatedAt',
    _$updatedAt,
  );

  static String _$id(AppConfig e) {
    return e.id;
  }

  static String _$key(AppConfig e) {
    return e.key;
  }

  static String? _$value(AppConfig e) {
    return e.value;
  }

  static String? _$description(AppConfig e) {
    return e.description;
  }

  static bool _$enabled(AppConfig e) {
    return e.enabled;
  }

  static DateTime? _$updatedAt(AppConfig e) {
    return e.updatedAt;
  }
}

extension AppConfigCompareE on AppConfig {
  Map<String, dynamic> compareToAppConfig(AppConfig other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (key != other.key) {
      diff['key'] = () => other.key;
    }

    if (value != other.value) {
      diff['value'] = () => other.value;
    }

    if (description != other.description) {
      diff['description'] = () => other.description;
    }

    if (enabled != other.enabled) {
      diff['enabled'] = () => other.enabled;
    }

    if (updatedAt != other.updatedAt) {
      diff['updatedAt'] = () => other.updatedAt;
    }
    return diff;
  }
}
