// dart format off
part of '../../../../src/core/params/params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class Params implements ZorphyValueBase {
  const Params.fromTrusted({this.params});

  final Map<String, dynamic>? params;

  static const ParamsLenses lenses = ParamsLenses();

  Params copyWith({Object? params = _sentinel}) {
    return Params.fromTrusted(
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Params && this.params == other.params;
  }

  @override
  int get hashCode => Object.hashAll([params]);

  @override
  String toString() => 'Params(params: $params)';

  static ZorphyBoundaryResult<Params> fromWire(Map<String, Object?> raw) {
    final violations = <FieldViolation>[];
    final Object? raw_params = raw['params'];
    Map<String, dynamic>? _params;
    if (raw_params != null) {
      final map_params = _boundaryObject(raw_params, '/params', violations);
      if (map_params != null) {
        final decoded_params = <String, dynamic>{};
        for (final entry in map_params.entries) {
          final path_params = '/params' + '/' + entry.key;
          final element_params = _boundaryAs<dynamic>(
            map_params[entry.key],
            path_params,
            violations,
          );
          if (element_params != null) {
            decoded_params[entry.key] = element_params;
          }
        }
        _params = decoded_params;
      }
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<Params>(targetType: 'Params', violations: violations);
    }
    return BoundaryOk<Params>(Params.fromTrusted(params: _params));
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [Params].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<Params, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/params' => ZorphyLens<Params, Object?>(
        path: '/params',
        get: (root) => root.params,
        set: (root, value) =>
            root.copyWith(params: value as Map<String, dynamic>?),
      ),
      _ => null,
    };
  }
}

class ParamsMockData {
  ParamsMockData._();

  static Params single({int seed = 0}) {
    return Params.fromTrusted();
  }

  static List<Params> list({int count = 10}) {
    return List<Params>.generate(count, (index) => single(seed: index));
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

/// Typed lenses over [Params] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `Params.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class ParamsLenses {
  const ParamsLenses();

  ZorphyLens<Params, Map<String, dynamic>?> get params =>
      const ZorphyLens<Params, Map<String, dynamic>?>(
        path: '/params',
        get: _getParams,
        set: _setParams,
      );

  static Map<String, dynamic>? _getParams(Params root) => root.params;

  static Params _setParams(Params root, Map<String, dynamic>? value) =>
      root.copyWith(params: value);
}

