// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'initialization_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class InitializationParams {
  final Duration timeout;
  final bool forceRefresh;
  final Params? params;
  final Params? credentials;
  final Params? settings;
  @JsonKey(
    includeFromJson: false,
    includeToJson: false,
    toJson: LocaleConverter.toJson,
    fromJson: LocaleConverter.fromJson,
  )
  final Locale? locale;

  const InitializationParams({
    required this.timeout,
    required this.forceRefresh,
    this.params,
    this.credentials,
    this.settings,
    this.locale,
  });

  InitializationParams copyWith({
    Duration? timeout,
    bool? forceRefresh,
    Params? params,
    Params? credentials,
    Params? settings,
    Locale? locale,
  }) {
    return InitializationParams(
      timeout: timeout ?? this.timeout,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      params: params ?? this.params,
      credentials: credentials ?? this.credentials,
      settings: settings ?? this.settings,
      locale: locale ?? this.locale,
    );
  }

  InitializationParams copyWithInitializationParams({
    Duration? timeout,
    bool? forceRefresh,
    Params? params,
    Params? credentials,
    Params? settings,
    Locale? locale,
  }) {
    return copyWith(
      timeout: timeout,
      forceRefresh: forceRefresh,
      params: params,
      credentials: credentials,
      settings: settings,
      locale: locale,
    );
  }

  InitializationParams patchWithInitializationParams({
    InitializationParamsPatch? patchInput,
  }) {
    final _patcher = patchInput ?? InitializationParamsPatch();
    final _patchMap = _patcher.toPatch();
    return InitializationParams(
      timeout: _patchMap.containsKey(InitializationParams$.timeout)
          ? (_patchMap[InitializationParams$.timeout] is Function)
                ? _patchMap[InitializationParams$.timeout](this.timeout)
                : _patchMap[InitializationParams$.timeout]
          : this.timeout,
      forceRefresh: _patchMap.containsKey(InitializationParams$.forceRefresh)
          ? (_patchMap[InitializationParams$.forceRefresh] is Function)
                ? _patchMap[InitializationParams$.forceRefresh](
                    this.forceRefresh,
                  )
                : _patchMap[InitializationParams$.forceRefresh]
          : this.forceRefresh,
      params: _patchMap.containsKey(InitializationParams$.params)
          ? (_patchMap[InitializationParams$.params] is Function)
                ? _patchMap[InitializationParams$.params](this.params)
                : _patchMap[InitializationParams$.params]
          : this.params,
      credentials: _patchMap.containsKey(InitializationParams$.credentials)
          ? (_patchMap[InitializationParams$.credentials] is Function)
                ? _patchMap[InitializationParams$.credentials](this.credentials)
                : _patchMap[InitializationParams$.credentials]
          : this.credentials,
      settings: _patchMap.containsKey(InitializationParams$.settings)
          ? (_patchMap[InitializationParams$.settings] is Function)
                ? _patchMap[InitializationParams$.settings](this.settings)
                : _patchMap[InitializationParams$.settings]
          : this.settings,
      locale: _patchMap.containsKey(InitializationParams$.locale)
          ? (_patchMap[InitializationParams$.locale] is Function)
                ? _patchMap[InitializationParams$.locale](this.locale)
                : _patchMap[InitializationParams$.locale]
          : this.locale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InitializationParams &&
        timeout == other.timeout &&
        forceRefresh == other.forceRefresh &&
        params == other.params &&
        credentials == other.credentials &&
        settings == other.settings &&
        locale == other.locale;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.timeout,
      this.forceRefresh,
      this.params,
      this.credentials,
      this.settings,
      this.locale,
    );
  }

  @override
  String toString() {
    return 'InitializationParams(' +
        'timeout: ${timeout}' +
        ', ' +
        'forceRefresh: ${forceRefresh}' +
        ', ' +
        'params: ${params}' +
        ', ' +
        'credentials: ${credentials}' +
        ', ' +
        'settings: ${settings}' +
        ', ' +
        'locale: ${locale})';
  }

  /// Creates a [InitializationParams] instance from JSON
  factory InitializationParams.fromJson(Map<String, dynamic> json) {
    final instance = _$InitializationParamsFromJson(json);
    return InitializationParams(
      timeout: instance.timeout,
      forceRefresh: instance.forceRefresh,
      params: instance.params,
      credentials: instance.credentials,
      settings: instance.settings,
      locale: json['locale'] != null
          ? LocaleConverter.fromJson(json['locale'] as Map<String, dynamic>)
                as Locale?
          : null,
    );
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
    if (locale != null) data['locale'] = LocaleConverter.toJson(locale!);
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

extension InitializationParamsPropertyHelpers on InitializationParams {
  bool get hasParams => params != null;
  bool get noParams => params == null;
  Params get paramsRequired =>
      params ?? (throw StateError('params is required but was null'));
  bool get hasCredentials => credentials != null;
  bool get noCredentials => credentials == null;
  Params get credentialsRequired =>
      credentials ?? (throw StateError('credentials is required but was null'));
  bool get hasSettings => settings != null;
  bool get noSettings => settings == null;
  Params get settingsRequired =>
      settings ?? (throw StateError('settings is required but was null'));
  bool get hasLocale => locale != null;
  bool get noLocale => locale == null;
  Locale get localeRequired =>
      locale ?? (throw StateError('locale is required but was null'));
}

extension InitializationParamsSerialization on InitializationParams {
  Map<String, dynamic> toJson() {
    final data = _$InitializationParamsToJson(this);
    if (locale != null) data['locale'] = LocaleConverter.toJson(locale!);
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
    if (locale != null) data['locale'] = LocaleConverter.toJson(locale!);
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

enum InitializationParams$ {
  timeout,
  forceRefresh,
  params,
  credentials,
  settings,
  locale,
}

class InitializationParamsPatch implements Patch<InitializationParams> {
  final Map<InitializationParams$, dynamic> _patch = {};

  static InitializationParamsPatch create([Map<String, dynamic>? diff]) {
    final patch = InitializationParamsPatch();
    if (diff != null) {
      diff.forEach((key, value) {
        try {
          final enumValue = InitializationParams$.values.firstWhere(
            (e) => e.name == key,
          );
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

  static InitializationParamsPatch fromPatch(
    Map<InitializationParams$, dynamic> patch,
  ) {
    final _patch = InitializationParamsPatch();
    _patch._patch.addAll(patch);
    return _patch;
  }

  Map<InitializationParams$, dynamic> toPatch() => Map.from(_patch);

  InitializationParams applyTo(InitializationParams entity) {
    return entity.patchWithInitializationParams(patchInput: this);
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

  static InitializationParamsPatch fromJson(Map<String, dynamic> json) {
    return create(json);
  }

  InitializationParamsPatch withTimeout(Duration? value) {
    _patch[InitializationParams$.timeout] = value;
    return this;
  }

  InitializationParamsPatch withForceRefresh(bool? value) {
    _patch[InitializationParams$.forceRefresh] = value;
    return this;
  }

  InitializationParamsPatch withParams(Params? value) {
    _patch[InitializationParams$.params] = value;
    return this;
  }

  InitializationParamsPatch withCredentials(Params? value) {
    _patch[InitializationParams$.credentials] = value;
    return this;
  }

  InitializationParamsPatch withSettings(Params? value) {
    _patch[InitializationParams$.settings] = value;
    return this;
  }

  InitializationParamsPatch withLocale(Locale? value) {
    _patch[InitializationParams$.locale] = value;
    return this;
  }
}

/// Field descriptors for [InitializationParams] query construction
abstract final class InitializationParamsFields {
  static Duration _$gettimeout(InitializationParams e) => e.timeout;
  static const timeout = Field<InitializationParams, Duration>(
    'timeout',
    _$gettimeout,
  );
  static bool _$getforceRefresh(InitializationParams e) => e.forceRefresh;
  static const forceRefresh = Field<InitializationParams, bool>(
    'forceRefresh',
    _$getforceRefresh,
  );
  static Params? _$getparams(InitializationParams e) => e.params;
  static const params = Field<InitializationParams, Params?>(
    'params',
    _$getparams,
  );
  static Params? _$getcredentials(InitializationParams e) => e.credentials;
  static const credentials = Field<InitializationParams, Params?>(
    'credentials',
    _$getcredentials,
  );
  static Params? _$getsettings(InitializationParams e) => e.settings;
  static const settings = Field<InitializationParams, Params?>(
    'settings',
    _$getsettings,
  );
  static Locale? _$getlocale(InitializationParams e) => e.locale;
  static const locale = Field<InitializationParams, Locale?>(
    'locale',
    _$getlocale,
  );
}

extension InitializationParamsCompareE on InitializationParams {
  Map<String, dynamic> compareToInitializationParams(
    InitializationParams other,
  ) {
    final Map<String, dynamic> diff = {};

    if (timeout != other.timeout) {
      diff['timeout'] = () => other.timeout;
    }
    if (forceRefresh != other.forceRefresh) {
      diff['forceRefresh'] = () => other.forceRefresh;
    }
    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (credentials != other.credentials) {
      diff['credentials'] = () => other.credentials;
    }
    if (settings != other.settings) {
      diff['settings'] = () => other.settings;
    }
    if (locale != other.locale) {
      diff['locale'] = () => other.locale;
    }
    return diff;
  }
}
