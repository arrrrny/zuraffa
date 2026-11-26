// dart format off
part of '../../../../src/core/params/settings.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class Settings implements ZorphyValueBase {
  Settings.fromTrusted({Map<String, dynamic>? params})
    : params = params == null ? null : Map<String, dynamic>.of(params);

  final Map<String, dynamic>? params;

  static const SettingsLenses lenses = SettingsLenses();

  Settings copyWith({Object? params = _sentinel}) {
    return Settings.fromTrusted(
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings &&
        Settings._zorphyCollectionEquals(this.params, other.params);
  }

  @override
  int get hashCode => Object.hashAll([Settings._zorphyCollectionHash(params)]);

  @override
  String toString() => 'Settings(params: $params)';

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

  static ZorphyBoundaryResult<Settings> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
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
      return BoundaryErr<Settings>(
        targetType: 'Settings',
        violations: violations,
      );
    }
    return BoundaryOk<Settings>(Settings.fromTrusted(params: _params));
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Settings].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Settings, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/params' => ZorphyLens<Settings, Object?>(
        path: '/params',
        get: (root) => root.params,
        set: (root, value) =>
            root.copyWith(params: value as Map<String, dynamic>?),
      ),
      _ => null,
    };
  }
}

class SettingsMockData {
  SettingsMockData._();

  static Settings single({int seed = 0}) {
    return Settings.fromTrusted(params: {});
  }

  static List<Settings> list({int count = 10}) {
    return List<Settings>.generate(count, (index) => single(seed: index));
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
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

/// Typed lenses over [Settings] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `Settings.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class SettingsLenses {
  const SettingsLenses();

  ZorphyLens<Settings, Map<String, dynamic>?> get params =>
      const ZorphyLens<Settings, Map<String, dynamic>?>(
        path: '/params',
        get: _getParams,
        set: _setParams,
      );

  static Map<String, dynamic>? _getParams(Settings root) => root.params;

  static Settings _setParams(Settings root, Map<String, dynamic>? value) =>
      root.copyWith(params: value);
}

/// Typed field descriptors over [Settings] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `SettingsFields.all`.
abstract final class SettingsFields {
  static const ZorphyField<Settings, Map<String, dynamic>?> params =
      ZorphyField<Settings, Map<String, dynamic>?>(
        name: 'params',
        jsonKey: 'params',
        pointer: '/params',
        get: _getParams,
        set: _setParams,
      );

  static final List<ZorphyField<Settings, Object?>> all = [params.asObject];

  static Map<String, dynamic>? _getParams(Settings root) => root.params;

  static Settings _setParams(Settings root, Map<String, dynamic>? value) =>
      root.copyWith(params: value);
}

