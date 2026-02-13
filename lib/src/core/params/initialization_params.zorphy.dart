// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'initialization_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class InitializationParams extends Params {
  @JsonKey()
  final Duration timeout;
  @JsonKey()
  final bool? forceRefresh;
  final Credentials? credentials;
  final Settings? settings;
  final Locale? locale;

  const InitializationParams({
    Map<String, dynamic>? params,
    Duration? timeout,
    bool? forceRefresh,
    this.credentials,
    this.settings,
    this.locale,
  }) : this.timeout = timeout ?? const Duration(seconds: 5),
       this.forceRefresh = forceRefresh ?? false,
       super(params: params);

  InitializationParams copyWith({
    Map<String, dynamic>? params,
    Duration? timeout,
    bool? forceRefresh,
    Credentials? credentials,
    Settings? settings,
    Locale? locale,
  }) {
    return InitializationParams(
      params: params ?? this.params,
      timeout: timeout ?? this.timeout,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      credentials: credentials ?? this.credentials,
      settings: settings ?? this.settings,
      locale: locale ?? this.locale,
    );
  }

  InitializationParams copyWithInitializationParams({
    Map<String, dynamic>? params,
    Duration? timeout,
    bool? forceRefresh,
    Credentials? credentials,
    Settings? settings,
    Locale? locale,
  }) {
    return copyWith(
      params: params,
      timeout: timeout,
      forceRefresh: forceRefresh,
      credentials: credentials,
      settings: settings,
      locale: locale,
    );
  }

  InitializationParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  InitializationParams patchWithInitializationParams({
    InitializationParamsPatch? patchInput,
  }) {
    final _patcher = patchInput ?? InitializationParamsPatch();
    final _patchMap = _patcher.toPatch();
    return InitializationParams(
      params: _patchMap.containsKey(InitializationParams$.params)
          ? (_patchMap[InitializationParams$.params] is Function)
                ? _patchMap[InitializationParams$.params](this.params)
                : _patchMap[InitializationParams$.params]
          : this.params,
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

  InitializationParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.toPatch();
    return InitializationParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : _patchMap[Params$.params]
          : this.params,
      timeout: this.timeout,
      forceRefresh: this.forceRefresh,
      credentials: this.credentials,
      settings: this.settings,
      locale: this.locale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InitializationParams &&
        params == other.params &&
        timeout == other.timeout &&
        forceRefresh == other.forceRefresh &&
        credentials == other.credentials &&
        settings == other.settings &&
        locale == other.locale;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.params,
      this.timeout,
      this.forceRefresh,
      this.credentials,
      this.settings,
      this.locale,
    );
  }

  @override
  String toString() {
    return 'InitializationParams(' +
        'params: ${params}' +
        ', ' +
        'timeout: ${timeout}' +
        ', ' +
        'forceRefresh: ${forceRefresh}' +
        ', ' +
        'credentials: ${credentials}' +
        ', ' +
        'settings: ${settings}' +
        ', ' +
        'locale: ${locale})';
  }

  /// Creates a [InitializationParams] instance from JSON
  factory InitializationParams.fromJson(Map<String, dynamic> json) =>
      _$InitializationParamsFromJson(json);

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
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
  bool get hasForceRefresh => forceRefresh != null;
  bool get noForceRefresh => forceRefresh == null;
  bool get forceRefreshRequired =>
      forceRefresh ??
      (throw StateError('forceRefresh is required but was null'));
  bool get hasCredentials => credentials != null;
  bool get noCredentials => credentials == null;
  Credentials get credentialsRequired =>
      credentials ?? (throw StateError('credentials is required but was null'));
  bool get hasSettings => settings != null;
  bool get noSettings => settings == null;
  Settings get settingsRequired =>
      settings ?? (throw StateError('settings is required but was null'));
  bool get hasLocale => locale != null;
  bool get noLocale => locale == null;
  Locale get localeRequired =>
      locale ?? (throw StateError('locale is required but was null'));
}

extension InitializationParamsSerialization on InitializationParams {
  Map<String, dynamic> toJson() {
    final data = _$InitializationParamsToJson(this);
    data['params'] = params;
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
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

enum InitializationParams$ {
  params,
  timeout,
  forceRefresh,
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

  InitializationParamsPatch withParams(Map<String, dynamic>? value) {
    _patch[InitializationParams$.params] = value;
    return this;
  }

  InitializationParamsPatch withTimeout(Duration? value) {
    _patch[InitializationParams$.timeout] = value;
    return this;
  }

  InitializationParamsPatch withForceRefresh(bool? value) {
    _patch[InitializationParams$.forceRefresh] = value;
    return this;
  }

  InitializationParamsPatch withCredentials(Credentials? value) {
    _patch[InitializationParams$.credentials] = value;
    return this;
  }

  InitializationParamsPatch withSettings(Settings? value) {
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
  static Map<String, dynamic>? _$getparams(InitializationParams e) => e.params;
  static const params = Field<InitializationParams, Map<String, dynamic>?>(
    'params',
    _$getparams,
  );
  static Duration _$gettimeout(InitializationParams e) => e.timeout;
  static const timeout = Field<InitializationParams, Duration>(
    'timeout',
    _$gettimeout,
  );
  static bool? _$getforceRefresh(InitializationParams e) => e.forceRefresh;
  static const forceRefresh = Field<InitializationParams, bool?>(
    'forceRefresh',
    _$getforceRefresh,
  );
  static Credentials? _$getcredentials(InitializationParams e) => e.credentials;
  static const credentials = Field<InitializationParams, Credentials?>(
    'credentials',
    _$getcredentials,
  );
  static Settings? _$getsettings(InitializationParams e) => e.settings;
  static const settings = Field<InitializationParams, Settings?>(
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

    if (params != other.params) {
      diff['params'] = () => other.params;
    }
    if (timeout != other.timeout) {
      diff['timeout'] = () => other.timeout;
    }
    if (forceRefresh != other.forceRefresh) {
      diff['forceRefresh'] = () => other.forceRefresh;
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
