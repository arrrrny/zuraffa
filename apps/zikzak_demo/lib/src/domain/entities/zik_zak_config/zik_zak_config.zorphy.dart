// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'zik_zak_config.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class ZikZakConfig {
  ZikZakConfig({
    String? id,
    required String this.environment,
    required String this.mode,
    required String this.logLevel,
    required Locale this.locale,
  }) : this.id = id ?? const Uuid().v4();

  factory ZikZakConfig.fromJson(Map<String, dynamic> json) =>
      _$ZikZakConfigFromJson(json);

  final String id;

  final String environment;

  final String mode;

  final String logLevel;

  final Locale locale;

  ZikZakConfig copyWith({
    String? id,
    String? environment,
    String? mode,
    String? logLevel,
    Locale? locale,
  }) {
    return ZikZakConfig(
      id: id ?? this.id,
      environment: environment ?? this.environment,
      mode: mode ?? this.mode,
      logLevel: logLevel ?? this.logLevel,
      locale: locale ?? this.locale,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  ZikZakConfig copyWithField<T>(Field<ZikZakConfig, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'environment':
        return copyWith(environment: value as String);
      case 'mode':
        return copyWith(mode: value as String);
      case 'logLevel':
        return copyWith(logLevel: value as String);
      case 'locale':
        return copyWith(locale: value as Locale);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'ZikZakConfig has no settable field with this name',
        );
    }
  }

  ZikZakConfig copyWithZikZakConfig({
    String? id,
    String? environment,
    String? mode,
    String? logLevel,
    Locale? locale,
  }) {
    return copyWith(
      id: id,
      environment: environment,
      mode: mode,
      logLevel: logLevel,
      locale: locale,
    );
  }

  ZikZakConfig patchWithZikZakConfig([ZikZakConfigPatch? patchInput]) {
    final _patcher = patchInput ?? ZikZakConfigPatch();
    final _patchMap = _patcher.patchMap;
    return ZikZakConfig(
      id: _patchMap.containsKey(ZikZakConfig$.id)
          ? ((_patchMap[ZikZakConfig$.id] is Function)
                    ? _patchMap[ZikZakConfig$.id](this.id)
                    : (_patchMap[ZikZakConfig$.id] is Patch)
                    ? _patchMap[ZikZakConfig$.id].applyTo(this.id)
                    : _patchMap[ZikZakConfig$.id])
                as String
          : this.id,
      environment: _patchMap.containsKey(ZikZakConfig$.environment)
          ? ((_patchMap[ZikZakConfig$.environment] is Function)
                    ? _patchMap[ZikZakConfig$.environment](this.environment)
                    : (_patchMap[ZikZakConfig$.environment] is Patch)
                    ? _patchMap[ZikZakConfig$.environment].applyTo(
                        this.environment,
                      )
                    : _patchMap[ZikZakConfig$.environment])
                as String
          : this.environment,
      mode: _patchMap.containsKey(ZikZakConfig$.mode)
          ? ((_patchMap[ZikZakConfig$.mode] is Function)
                    ? _patchMap[ZikZakConfig$.mode](this.mode)
                    : (_patchMap[ZikZakConfig$.mode] is Patch)
                    ? _patchMap[ZikZakConfig$.mode].applyTo(this.mode)
                    : _patchMap[ZikZakConfig$.mode])
                as String
          : this.mode,
      logLevel: _patchMap.containsKey(ZikZakConfig$.logLevel)
          ? ((_patchMap[ZikZakConfig$.logLevel] is Function)
                    ? _patchMap[ZikZakConfig$.logLevel](this.logLevel)
                    : (_patchMap[ZikZakConfig$.logLevel] is Patch)
                    ? _patchMap[ZikZakConfig$.logLevel].applyTo(this.logLevel)
                    : _patchMap[ZikZakConfig$.logLevel])
                as String
          : this.logLevel,
      locale: _patchMap.containsKey(ZikZakConfig$.locale)
          ? ((_patchMap[ZikZakConfig$.locale] is Function)
                    ? _patchMap[ZikZakConfig$.locale](this.locale)
                    : (_patchMap[ZikZakConfig$.locale] is Patch)
                    ? _patchMap[ZikZakConfig$.locale].applyTo(this.locale)
                    : _patchMap[ZikZakConfig$.locale])
                as Locale
          : this.locale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZikZakConfig &&
        id == other.id &&
        environment == other.environment &&
        mode == other.mode &&
        logLevel == other.logLevel &&
        locale == other.locale;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.environment,
      this.mode,
      this.logLevel,
      this.locale,
    );
  }

  @override
  String toString() {
    return 'ZikZakConfig(' +
        'id: ${id}' +
        ', ' +
        'environment: ${environment}' +
        ', ' +
        'mode: ${mode}' +
        ', ' +
        'logLevel: ${logLevel}' +
        ', ' +
        'locale: ${locale})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is ZikZakConfig &&
        environment == other.environment &&
        mode == other.mode &&
        logLevel == other.logLevel &&
        locale == other.locale;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$ZikZakConfigToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$ZikZakConfigToJson(this);
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

extension ZikZakConfigPropertyHelpers on ZikZakConfig {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasEnvironment {
    return this.environment.isNotEmpty;
  }

  bool get noEnvironment {
    return this.environment.isEmpty;
  }

  bool get hasMode {
    return this.mode.isNotEmpty;
  }

  bool get noMode {
    return this.mode.isEmpty;
  }

  bool get hasLogLevel {
    return this.logLevel.isNotEmpty;
  }

  bool get noLogLevel {
    return this.logLevel.isEmpty;
  }
}

extension ZikZakConfigSerialization on ZikZakConfig {
  Map<String, dynamic> toJson() {
    return _$ZikZakConfigToJson(this);
  }
}

enum ZikZakConfig$ { id, environment, mode, logLevel, locale }

class ZikZakConfigPatch extends PatchBase<ZikZakConfig, ZikZakConfig$> {
  ZikZakConfig applyTo(ZikZakConfig entity) {
    return entity.patchWithZikZakConfig(this);
  }

  ZikZakConfigPatch withId(String? value) {
    patchMap[ZikZakConfig$.id] = value;
    return this;
  }

  ZikZakConfigPatch withEnvironment(String? value) {
    patchMap[ZikZakConfig$.environment] = value;
    return this;
  }

  ZikZakConfigPatch withMode(String? value) {
    patchMap[ZikZakConfig$.mode] = value;
    return this;
  }

  ZikZakConfigPatch withLogLevel(String? value) {
    patchMap[ZikZakConfig$.logLevel] = value;
    return this;
  }

  ZikZakConfigPatch withLocale(Locale? value) {
    patchMap[ZikZakConfig$.locale] = value;
    return this;
  }

  ZikZakConfigPatch withLocalePatch(LocalePatch patch) {
    patchMap[ZikZakConfig$.locale] = patch;
    return this;
  }

  ZikZakConfigPatch withLocalePatchFunc(
    LocalePatch Function(LocalePatch) patch,
  ) {
    patchMap[ZikZakConfig$.locale] = (dynamic current) {
      var currentPatch = LocalePatch();
      return patch(currentPatch).applyTo(current as Locale);
    };
    return this;
  }
}

/// Field descriptors for [ZikZakConfig] query construction
abstract final class ZikZakConfigFields {
  static const id = Field<ZikZakConfig, String>('id', _$id);

  static const environment = Field<ZikZakConfig, String>(
    'environment',
    _$environment,
  );

  static const mode = Field<ZikZakConfig, String>('mode', _$mode);

  static const logLevel = Field<ZikZakConfig, String>('logLevel', _$logLevel);

  static const locale = Field<ZikZakConfig, Locale>('locale', _$locale);

  static String _$id(ZikZakConfig e) {
    return e.id;
  }

  static String _$environment(ZikZakConfig e) {
    return e.environment;
  }

  static String _$mode(ZikZakConfig e) {
    return e.mode;
  }

  static String _$logLevel(ZikZakConfig e) {
    return e.logLevel;
  }

  static Locale _$locale(ZikZakConfig e) {
    return e.locale;
  }
}

extension ZikZakConfigCompareE on ZikZakConfig {
  Map<String, dynamic> compareToZikZakConfig(ZikZakConfig other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (environment != other.environment) {
      diff['environment'] = () => other.environment;
    }

    if (mode != other.mode) {
      diff['mode'] = () => other.mode;
    }

    if (logLevel != other.logLevel) {
      diff['logLevel'] = () => other.logLevel;
    }

    if (locale != other.locale) {
      diff['locale'] = () => other.locale;
    }
    return diff;
  }
}
