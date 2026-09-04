// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'initialization_params.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class InitializationParams extends Params {
  const InitializationParams({
    Map<String, dynamic>? this.params,
    required Duration this.timeout,
    bool? forceRefresh,
    Credentials? this.credentials,
    Settings? this.settings,
  }) : this.forceRefresh = forceRefresh ?? false,
       super();

  factory InitializationParams.fromJson(Map<String, dynamic> json) =>
      _$InitializationParamsFromJson(json);

  @override
  final Map<String, dynamic>? params;

  @JsonKey(
    toJson: DurationConverter.durationToJson,
    fromJson: DurationConverter.durationFromJson,
  )
  final Duration timeout;

  @JsonKey(defaultValue: false)
  final bool? forceRefresh;

  final Credentials? credentials;

  final Settings? settings;

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

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  InitializationParams copyWithField<T>(
    Field<InitializationParams, T> field,
    T value,
  ) {
    switch (field.name) {
      case 'params':
        return copyWith(params: value as Map<String, dynamic>?);
      case 'timeout':
        return copyWith(timeout: value as Duration);
      case 'forceRefresh':
        return copyWith(forceRefresh: value as bool?);
      case 'credentials':
        return copyWith(credentials: value as Credentials?);
      case 'settings':
        return copyWith(settings: value as Settings?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'InitializationParams has no settable field with this name',
        );
    }
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

  InitializationParams patchWithInitializationParams([
    InitializationParamsPatch? patchInput,
  ]) {
    final _patcher = patchInput ?? InitializationParamsPatch();
    final _patchMap = _patcher.patchMap;
    return InitializationParams(
      params: _patchMap.containsKey(InitializationParams$.params)
          ? ((_patchMap[InitializationParams$.params] is Function)
                    ? _patchMap[InitializationParams$.params](this.params)
                    : (_patchMap[InitializationParams$.params] is Patch)
                    ? _patchMap[InitializationParams$.params].applyTo(
                        this.params,
                      )
                    : _patchMap[InitializationParams$.params])
                as Map<String, dynamic>?
          : this.params,
      timeout: _patchMap.containsKey(InitializationParams$.timeout)
          ? ((_patchMap[InitializationParams$.timeout] is Function)
                    ? _patchMap[InitializationParams$.timeout](this.timeout)
                    : (_patchMap[InitializationParams$.timeout] is Patch)
                    ? _patchMap[InitializationParams$.timeout].applyTo(
                        this.timeout,
                      )
                    : _patchMap[InitializationParams$.timeout])
                as Duration
          : this.timeout,
      forceRefresh: _patchMap.containsKey(InitializationParams$.forceRefresh)
          ? ((_patchMap[InitializationParams$.forceRefresh] is Function)
                    ? _patchMap[InitializationParams$.forceRefresh](
                        this.forceRefresh,
                      )
                    : (_patchMap[InitializationParams$.forceRefresh] is Patch)
                    ? _patchMap[InitializationParams$.forceRefresh].applyTo(
                        this.forceRefresh,
                      )
                    : _patchMap[InitializationParams$.forceRefresh])
                as bool?
          : this.forceRefresh,
      credentials: _patchMap.containsKey(InitializationParams$.credentials)
          ? ((_patchMap[InitializationParams$.credentials] is Function)
                    ? _patchMap[InitializationParams$.credentials](
                        this.credentials,
                      )
                    : (_patchMap[InitializationParams$.credentials] is Patch)
                    ? _patchMap[InitializationParams$.credentials].applyTo(
                        this.credentials,
                      )
                    : _patchMap[InitializationParams$.credentials])
                as Credentials?
          : this.credentials,
      settings: _patchMap.containsKey(InitializationParams$.settings)
          ? ((_patchMap[InitializationParams$.settings] is Function)
                    ? _patchMap[InitializationParams$.settings](this.settings)
                    : (_patchMap[InitializationParams$.settings] is Patch)
                    ? _patchMap[InitializationParams$.settings].applyTo(
                        this.settings,
                      )
                    : _patchMap[InitializationParams$.settings])
                as Settings?
          : this.settings,
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

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$InitializationParamsToJson(this);
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

extension InitializationParamsPropertyHelpers on InitializationParams {
  bool get hasForceRefresh {
    return this.forceRefresh != null;
  }

  bool get noForceRefresh {
    return this.forceRefresh == null;
  }

  bool get forceRefreshRequired {
    return this.forceRefresh ??
        (throw StateError('forceRefresh is required but was null'));
  }

  bool get hasCredentials {
    return this.credentials != null;
  }

  bool get noCredentials {
    return this.credentials == null;
  }

  Credentials get credentialsRequired {
    return this.credentials ??
        (throw StateError('credentials is required but was null'));
  }

  bool get hasSettings {
    return this.settings != null;
  }

  bool get noSettings {
    return this.settings == null;
  }

  Settings get settingsRequired {
    return this.settings ??
        (throw StateError('settings is required but was null'));
  }
}

extension InitializationParamsSerialization on InitializationParams {
  Map<String, dynamic> toJson() {
    return _$InitializationParamsToJson(this);
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
    return entity.patchWithInitializationParams(this);
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

  InitializationParamsPatch withSettingsPatch(SettingsPatch patch) {
    patchMap[InitializationParams$.settings] = patch;
    return this;
  }

  InitializationParamsPatch withSettingsPatchFunc(
    SettingsPatch Function(SettingsPatch) patch,
  ) {
    patchMap[InitializationParams$.settings] = (dynamic current) {
      var currentPatch = SettingsPatch();
      return patch(currentPatch).applyTo(current as Settings);
    };
    return this;
  }
}

/// Field descriptors for [InitializationParams] query construction
abstract final class InitializationParamsFields {
  static const params = Field<InitializationParams, Map<String, dynamic>?>(
    'params',
    _$params,
  );

  static const timeout = Field<InitializationParams, Duration>(
    'timeout',
    _$timeout,
  );

  static const forceRefresh = Field<InitializationParams, bool?>(
    'forceRefresh',
    _$forceRefresh,
  );

  static const credentials = Field<InitializationParams, Credentials?>(
    'credentials',
    _$credentials,
  );

  static const settings = Field<InitializationParams, Settings?>(
    'settings',
    _$settings,
  );

  static Map<String, dynamic>? _$params(InitializationParams e) {
    return e.params;
  }

  static Duration _$timeout(InitializationParams e) {
    return e.timeout;
  }

  static bool? _$forceRefresh(InitializationParams e) {
    return e.forceRefresh;
  }

  static Credentials? _$credentials(InitializationParams e) {
    return e.credentials;
  }

  static Settings? _$settings(InitializationParams e) {
    return e.settings;
  }
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
