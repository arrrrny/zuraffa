// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'initialization_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true)
class InitializationParams extends Params {
  @JsonKey(
    toJson: DurationConverter.durationToJson,
    fromJson: DurationConverter.durationFromJson,
  )
  final Duration timeout;
  @JsonKey(defaultValue: false)
  final bool? forceRefresh;
  final Credentials? credentials;
  final Settings? settings;

  const InitializationParams({
    Map<String, dynamic>? params,
    required this.timeout,
    bool? forceRefresh,
    this.credentials,
    this.settings,
  }) : this.forceRefresh = forceRefresh ?? false,
       super(params: params);

  InitializationParams copyWith({
    Map<String, dynamic>? params,
    Duration? timeout,
    bool? forceRefresh,
    Credentials? credentials,
    Settings? settings,
  }) {
    return InitializationParams(
      params: params ?? this.params,
      timeout: timeout ?? this.timeout,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      credentials: credentials ?? this.credentials,
      settings: settings ?? this.settings,
    );
  }

  InitializationParams copyWithInitializationParams({
    Map<String, dynamic>? params,
    Duration? timeout,
    bool? forceRefresh,
    Credentials? credentials,
    Settings? settings,
  }) {
    return copyWith(
      params: params,
      timeout: timeout,
      forceRefresh: forceRefresh,
      credentials: credentials,
      settings: settings,
    );
  }

  InitializationParams copyWithParams({Map<String, dynamic>? params}) {
    return copyWith(params: params);
  }

  InitializationParams patchWithInitializationParams({
    InitializationParamsPatch? patchInput,
  }) {
    final _patcher = patchInput ?? InitializationParamsPatch();
    final _patchMap = _patcher.patchMap;
    return InitializationParams(
      params: _patchMap.containsKey(InitializationParams$.params)
          ? (_patchMap[InitializationParams$.params] is Function)
                ? _patchMap[InitializationParams$.params](this.params)
                : (_patchMap[InitializationParams$.params] is Patch)
                ? _patchMap[InitializationParams$.params].applyTo(this.params)
                : _patchMap[InitializationParams$.params]
          : this.params,
      timeout: _patchMap.containsKey(InitializationParams$.timeout)
          ? (_patchMap[InitializationParams$.timeout] is Function)
                ? _patchMap[InitializationParams$.timeout](this.timeout)
                : (_patchMap[InitializationParams$.timeout] is Patch)
                ? _patchMap[InitializationParams$.timeout].applyTo(this.timeout)
                : _patchMap[InitializationParams$.timeout]
          : this.timeout,
      forceRefresh: _patchMap.containsKey(InitializationParams$.forceRefresh)
          ? (_patchMap[InitializationParams$.forceRefresh] is Function)
                ? _patchMap[InitializationParams$.forceRefresh](
                    this.forceRefresh,
                  )
                : (_patchMap[InitializationParams$.forceRefresh] is Patch)
                ? _patchMap[InitializationParams$.forceRefresh].applyTo(
                    this.forceRefresh,
                  )
                : _patchMap[InitializationParams$.forceRefresh]
          : this.forceRefresh,
      credentials: _patchMap.containsKey(InitializationParams$.credentials)
          ? (_patchMap[InitializationParams$.credentials] is Function)
                ? _patchMap[InitializationParams$.credentials](this.credentials)
                : (_patchMap[InitializationParams$.credentials] is Patch)
                ? _patchMap[InitializationParams$.credentials].applyTo(
                    this.credentials,
                  )
                : _patchMap[InitializationParams$.credentials]
          : this.credentials,
      settings: _patchMap.containsKey(InitializationParams$.settings)
          ? (_patchMap[InitializationParams$.settings] is Function)
                ? _patchMap[InitializationParams$.settings](this.settings)
                : (_patchMap[InitializationParams$.settings] is Patch)
                ? _patchMap[InitializationParams$.settings].applyTo(
                    this.settings,
                  )
                : _patchMap[InitializationParams$.settings]
          : this.settings,
    );
  }

  InitializationParams patchWithParams({ParamsPatch? patchInput}) {
    final _patcher = patchInput ?? ParamsPatch();
    final _patchMap = _patcher.patchMap;
    return InitializationParams(
      params: _patchMap.containsKey(Params$.params)
          ? (_patchMap[Params$.params] is Function)
                ? _patchMap[Params$.params](this.params)
                : (_patchMap[Params$.params] is Patch)
                ? _patchMap[Params$.params].applyTo(this.params)
                : _patchMap[Params$.params]
          : this.params,
      timeout: this.timeout,
      forceRefresh: this.forceRefresh,
      credentials: this.credentials,
      settings: this.settings,
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
        settings == other.settings;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.params,
      this.timeout,
      this.forceRefresh,
      this.credentials,
      this.settings,
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
        'settings: ${settings})';
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
}

extension InitializationParamsSerialization on InitializationParams {
  Map<String, dynamic> toJson() => _$InitializationParamsToJson(this);
  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
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

enum InitializationParams$ {
  params,
  timeout,
  forceRefresh,
  credentials,
  settings,
}

class InitializationParamsPatch
    extends PatchBase<InitializationParams, InitializationParams$> {
  InitializationParams applyTo(InitializationParams entity) {
    return entity.patchWithInitializationParams(patchInput: this);
  }

  InitializationParamsPatch withParams(Map<String, dynamic>? value) {
    patchMap[InitializationParams$.params] = value;
    return this;
  }

  InitializationParamsPatch withTimeout(Duration? value) {
    patchMap[InitializationParams$.timeout] = value;
    return this;
  }

  InitializationParamsPatch withForceRefresh(bool? value) {
    patchMap[InitializationParams$.forceRefresh] = value;
    return this;
  }

  InitializationParamsPatch withCredentials(Credentials? value) {
    patchMap[InitializationParams$.credentials] = value;
    return this;
  }

  InitializationParamsPatch withCredentialsPatch(CredentialsPatch patch) {
    patchMap[InitializationParams$.credentials] = patch;
    return this;
  }

  InitializationParamsPatch withCredentialsPatchFunc(
    CredentialsPatch Function(CredentialsPatch) patch,
  ) {
    patchMap[InitializationParams$.credentials] = (dynamic current) {
      var currentPatch = CredentialsPatch();
      return patch(currentPatch).applyTo(current as Credentials);
    };
    return this;
  }

  InitializationParamsPatch withSettings(Settings? value) {
    patchMap[InitializationParams$.settings] = value;
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
    return diff;
  }
}
