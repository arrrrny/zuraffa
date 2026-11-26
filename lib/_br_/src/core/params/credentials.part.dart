// dart format off
part of '../../../../src/core/params/credentials.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class Credentials implements ZorphyValueBase {
  const Credentials.fromTrusted({this.params});

  final Map<String, dynamic>? params;

  static const CredentialsLenses lenses = CredentialsLenses();

  Credentials copyWith({Object? params = _sentinel}) {
    return Credentials.fromTrusted(
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Credentials && this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([params]);

  @override
  String toString() => 'Credentials(params: $params)';

  static ZorphyBoundaryResult<Credentials> fromWire(Map<String, Object?> raw) {
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
      return BoundaryErr<Credentials>(
        targetType: 'Credentials',
        violations: violations,
      );
    }
    return BoundaryOk<Credentials>(Credentials.fromTrusted(params: _params));
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Credentials].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Credentials, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/params' => ZorphyLens<Credentials, Object?>(
        path: '/params',
        get: (root) => root.params,
        set: (root, value) =>
            root.copyWith(params: value as Map<String, dynamic>?),
      ),
      _ => null,
    };
  }
}

class CredentialsMockData {
  CredentialsMockData._();

  static Credentials single({int seed = 0}) {
    return Credentials.fromTrusted();
  }

  static List<Credentials> list({int count = 10}) {
    return List<Credentials>.generate(count, (index) => single(seed: index));
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

/// Typed lenses over [Credentials] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `Credentials.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class CredentialsLenses {
  const CredentialsLenses();

  ZorphyLens<Credentials, Map<String, dynamic>?> get params =>
      const ZorphyLens<Credentials, Map<String, dynamic>?>(
        path: '/params',
        get: _getParams,
        set: _setParams,
      );

  static Map<String, dynamic>? _getParams(Credentials root) => root.params;

  static Credentials _setParams(
    Credentials root,
    Map<String, dynamic>? value,
  ) => root.copyWith(params: value);
}

