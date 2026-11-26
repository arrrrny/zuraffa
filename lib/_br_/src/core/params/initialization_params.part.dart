// dart format off
part of '../../../../src/core/params/initialization_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class InitializationParams implements ZorphyValueBase {
  InitializationParams.fromTrusted({
    required this.timeout,
    this.forceRefresh,
    this.credentials,
    this.settings,
    Map<String, dynamic>? params,
  }) : params = params == null ? null : Map<String, dynamic>.of(params);

  final Duration timeout;

  final bool? forceRefresh;

  final Credentials? credentials;

  final Settings? settings;

  final Map<String, dynamic>? params;

  static const InitializationParamsLenses lenses = InitializationParamsLenses();

  InitializationParams copyWith({
    Duration? timeout,
    Object? forceRefresh = _sentinel,
    Object? credentials = _sentinel,
    Object? settings = _sentinel,
    Object? params = _sentinel,
  }) {
    return InitializationParams.fromTrusted(
      timeout: timeout ?? this.timeout,
      forceRefresh: identical(forceRefresh, _sentinel)
          ? this.forceRefresh
          : forceRefresh as bool?,
      credentials: identical(credentials, _sentinel)
          ? this.credentials
          : credentials as Credentials?,
      settings: identical(settings, _sentinel)
          ? this.settings
          : settings as Settings?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InitializationParams &&
        this.timeout == other.timeout &&
        this.forceRefresh == other.forceRefresh &&
        this.credentials == other.credentials &&
        this.settings == other.settings &&
        InitializationParams._zorphyCollectionEquals(this.params, other.params);
  }

  @override
  int get hashCode => Object.hashAll([
    timeout,
    forceRefresh,
    credentials,
    settings,
    InitializationParams._zorphyCollectionHash(params),
  ]);

  @override
  String toString() =>
      'InitializationParams(timeout: $timeout, forceRefresh: $forceRefresh, credentials: $credentials, settings: $settings, params: $params)';

  static bool _zorphyCollectionEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every(b.contains);
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static int _zorphyCollectionHash(Object? value) {
    if (value is List) return Object.hashAll(value);
    if (value is Set) {
      return value.fold<int>(0, (hash, element) => hash + element.hashCode);
    }
    if (value is Map) {
      return value.entries.fold<int>(
        0,
        (hash, entry) => hash + Object.hash(entry.key, entry.value),
      );
    }
    return value.hashCode;
  }

  static ZorphyBoundaryResult<InitializationParams> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_timeout = raw['timeout'];
    Duration? _timeout;
    _timeout = _boundaryAs<Duration>(raw_timeout, '/timeout', violations);
    final Object? raw_forceRefresh = raw['forceRefresh'];
    bool? _forceRefresh;
    if (raw_forceRefresh != null) {
      _forceRefresh = _boundaryAs<bool>(
        raw_forceRefresh,
        '/forceRefresh',
        violations,
      );
    }
    final Object? raw_credentials = raw['credentials'];
    Credentials? _credentials;
    if (raw_credentials != null) {
      final map_credentials = _boundaryObject(
        raw_credentials,
        '/credentials',
        violations,
      );
      if (map_credentials != null) {
        Credentials.fromWire(map_credentials).fold(
          (value) {
            _credentials = value;
          },
          (error) => violations.addAll(
            _boundaryPrefix(error.violations, '/credentials'),
          ),
        );
      }
    }
    final Object? raw_settings = raw['settings'];
    Settings? _settings;
    if (raw_settings != null) {
      final map_settings = _boundaryObject(
        raw_settings,
        '/settings',
        violations,
      );
      if (map_settings != null) {
        Settings.fromWire(map_settings).fold(
          (value) {
            _settings = value;
          },
          (error) =>
              violations.addAll(_boundaryPrefix(error.violations, '/settings')),
        );
      }
    }
    final Object? raw_params = raw['params'];
    Map<String, dynamic>? _params;
    if (raw_params != null) {
      final map_params = _boundaryObject(raw_params, '/params', violations);
      if (map_params != null) {
        final decoded_params = <String, dynamic>{};
        for (final entry in map_params.entries) {
          final path_params = '/params' + '/' + entry.key;
          if (map_params[entry.key] == null) {
            decoded_params[entry.key] = null;
          } else {
            final element_params = _boundaryAs<dynamic>(
              map_params[entry.key],
              path_params,
              violations,
            );
            if (element_params != null) {
              decoded_params[entry.key] = element_params;
            }
          }
        }
        _params = decoded_params;
      }
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<InitializationParams>(
        targetType: 'InitializationParams',
        violations: violations,
      );
    }
    return BoundaryOk<InitializationParams>(
      InitializationParams.fromTrusted(
        timeout: _timeout!,
        forceRefresh: _forceRefresh,
        credentials: _credentials,
        settings: _settings,
        params: _params,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    map['timeout'] = this.timeout;
    final _forceRefresh = this.forceRefresh;
    if (_forceRefresh != null) {
      map['forceRefresh'] = _forceRefresh;
    }
    final _credentials = this.credentials;
    if (_credentials != null) {
      map['credentials'] = _credentials.toWire();
    }
    final _settings = this.settings;
    if (_settings != null) {
      map['settings'] = _settings.toWire();
    }
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [InitializationParams].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<InitializationParams, Object?>? resolvePath(
    String pointer,
  ) {
    return switch (pointer) {
      '/timeout' => ZorphyLens<InitializationParams, Object?>(
        path: '/timeout',
        get: (root) => root.timeout,
        set: (root, value) => root.copyWith(timeout: value as Duration),
      ),
      '/forceRefresh' => ZorphyLens<InitializationParams, Object?>(
        path: '/forceRefresh',
        get: (root) => root.forceRefresh,
        set: (root, value) => root.copyWith(forceRefresh: value as bool?),
      ),
      '/credentials' => ZorphyLens<InitializationParams, Object?>(
        path: '/credentials',
        get: (root) => root.credentials,
        set: (root, value) => root.copyWith(credentials: value as Credentials?),
      ),
      '/settings' => ZorphyLens<InitializationParams, Object?>(
        path: '/settings',
        get: (root) => root.settings,
        set: (root, value) => root.copyWith(settings: value as Settings?),
      ),
      '/params' => ZorphyLens<InitializationParams, Object?>(
        path: '/params',
        get: (root) => root.params,
        set: (root, value) =>
            root.copyWith(params: value as Map<String, dynamic>?),
      ),
      _ => null,
    };
  }
}

class InitializationParamsMockData {
  InitializationParamsMockData._();

  static InitializationParams single({int seed = 0}) {
    return InitializationParams.fromTrusted(
      timeout: Duration(hours: seed + 945),
      forceRefresh: (seed + 176) % 2 == 0,
      params: {},
    );
  }

  static List<InitializationParams> list({int count = 10}) {
    return List<InitializationParams>.generate(
      count,
      (index) => single(seed: index),
    );
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
}

List<FieldViolation> _boundaryPrefix(
  List<FieldViolation> violations,
  String path,
) {
  return violations
      .map(
        (violation) => FieldViolation(
          path: path + violation.path,
          expected: violation.expected,
          actual: violation.actual,
        ),
      )
      .toList();
}

T? _boundaryAs<T>(Object? value, String path, List<FieldViolation> violations) {
  if (value is T) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: '$T',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

Map<String, Object?>? _boundaryObject(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is Map<String, Object?>) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: 'Map<String, Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

/// Typed lenses over [InitializationParams] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `InitializationParams.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class InitializationParamsLenses {
  const InitializationParamsLenses();

  ZorphyLens<InitializationParams, Duration> get timeout =>
      const ZorphyLens<InitializationParams, Duration>(
        path: '/timeout',
        get: _getTimeout,
        set: _setTimeout,
      );

  static Duration _getTimeout(InitializationParams root) => root.timeout;

  static InitializationParams _setTimeout(
    InitializationParams root,
    Duration value,
  ) => root.copyWith(timeout: value);

  ZorphyLens<InitializationParams, bool?> get forceRefresh =>
      const ZorphyLens<InitializationParams, bool?>(
        path: '/forceRefresh',
        get: _getForceRefresh,
        set: _setForceRefresh,
      );

  static bool? _getForceRefresh(InitializationParams root) => root.forceRefresh;

  static InitializationParams _setForceRefresh(
    InitializationParams root,
    bool? value,
  ) => root.copyWith(forceRefresh: value);

  ZorphyLens<InitializationParams, Credentials?> get credentials =>
      const ZorphyLens<InitializationParams, Credentials?>(
        path: '/credentials',
        get: _getCredentials,
        set: _setCredentials,
      );

  static Credentials? _getCredentials(InitializationParams root) =>
      root.credentials;

  static InitializationParams _setCredentials(
    InitializationParams root,
    Credentials? value,
  ) => root.copyWith(credentials: value);

  ZorphyLens<InitializationParams, Settings?> get settings =>
      const ZorphyLens<InitializationParams, Settings?>(
        path: '/settings',
        get: _getSettings,
        set: _setSettings,
      );

  static Settings? _getSettings(InitializationParams root) => root.settings;

  static InitializationParams _setSettings(
    InitializationParams root,
    Settings? value,
  ) => root.copyWith(settings: value);

  ZorphyLens<InitializationParams, Map<String, dynamic>?> get params =>
      const ZorphyLens<InitializationParams, Map<String, dynamic>?>(
        path: '/params',
        get: _getParams,
        set: _setParams,
      );

  static Map<String, dynamic>? _getParams(InitializationParams root) =>
      root.params;

  static InitializationParams _setParams(
    InitializationParams root,
    Map<String, dynamic>? value,
  ) => root.copyWith(params: value);
}

/// Typed field descriptors over [InitializationParams] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `InitializationParamsFields.all`.
abstract final class InitializationParamsFields {
  static const ZorphyField<InitializationParams, Duration> timeout =
      ZorphyField<InitializationParams, Duration>(
        name: 'timeout',
        jsonKey: 'timeout',
        pointer: '/timeout',
        get: _getTimeout,
        set: _setTimeout,
      );

  static const ZorphyField<InitializationParams, bool?> forceRefresh =
      ZorphyField<InitializationParams, bool?>(
        name: 'forceRefresh',
        jsonKey: 'forceRefresh',
        pointer: '/forceRefresh',
        get: _getForceRefresh,
        set: _setForceRefresh,
      );

  static const ZorphyField<InitializationParams, Credentials?> credentials =
      ZorphyField<InitializationParams, Credentials?>(
        name: 'credentials',
        jsonKey: 'credentials',
        pointer: '/credentials',
        get: _getCredentials,
        set: _setCredentials,
      );

  static const ZorphyField<InitializationParams, Settings?> settings =
      ZorphyField<InitializationParams, Settings?>(
        name: 'settings',
        jsonKey: 'settings',
        pointer: '/settings',
        get: _getSettings,
        set: _setSettings,
      );

  static const ZorphyField<InitializationParams, Map<String, dynamic>?> params =
      ZorphyField<InitializationParams, Map<String, dynamic>?>(
        name: 'params',
        jsonKey: 'params',
        pointer: '/params',
        get: _getParams,
        set: _setParams,
      );

  static final List<ZorphyField<InitializationParams, Object?>> all = [
    timeout.asObject,
    forceRefresh.asObject,
    credentials.asObject,
    settings.asObject,
    params.asObject,
  ];

  static Duration _getTimeout(InitializationParams root) => root.timeout;

  static InitializationParams _setTimeout(
    InitializationParams root,
    Duration value,
  ) => root.copyWith(timeout: value);

  static bool? _getForceRefresh(InitializationParams root) => root.forceRefresh;

  static InitializationParams _setForceRefresh(
    InitializationParams root,
    bool? value,
  ) => root.copyWith(forceRefresh: value);

  static Credentials? _getCredentials(InitializationParams root) =>
      root.credentials;

  static InitializationParams _setCredentials(
    InitializationParams root,
    Credentials? value,
  ) => root.copyWith(credentials: value);

  static Settings? _getSettings(InitializationParams root) => root.settings;

  static InitializationParams _setSettings(
    InitializationParams root,
    Settings? value,
  ) => root.copyWith(settings: value);

  static Map<String, dynamic>? _getParams(InitializationParams root) =>
      root.params;

  static InitializationParams _setParams(
    InitializationParams root,
    Map<String, dynamic>? value,
  ) => root.copyWith(params: value);
}

