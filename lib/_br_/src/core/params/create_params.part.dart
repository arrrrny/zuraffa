// dart format off
part of '../../../../src/core/params/create_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class CreateParams<T> implements ZorphyValueBase {
  CreateParams.fromTrusted({required this.data, Map<String, dynamic>? params})
    : params = params == null ? null : Map<String, dynamic>.of(params);

  final T data;

  final Map<String, dynamic>? params;

  CreateParams<T> copyWith({T? data, Object? params = _sentinel}) {
    return CreateParams<T>.fromTrusted(
      data: data ?? this.data,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateParams &&
        CreateParams._zorphyCollectionEquals(this.data, other.data) &&
        CreateParams._zorphyCollectionEquals(this.params, other.params);
  }

  @override
  int get hashCode => Object.hashAll([
    CreateParams._zorphyCollectionHash(data),
    CreateParams._zorphyCollectionHash(params),
  ]);

  @override
  String toString() => 'CreateParams(data: $data, params: $params)';

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

  static ZorphyBoundaryResult<CreateParams<T>> fromWire<T>(
    Map<String, Object?> raw,
    ZorphyBoundaryResult<T> Function(Map<String, Object?> raw) decodeT,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_data = raw['data'];
    T? _data;
    final map_data = _boundaryObject(raw_data, '/data', violations);
    if (map_data != null) {
      decodeT(map_data).fold(
        (value) {
          _data = value;
        },
        (error) =>
            violations.addAll(_boundaryPrefix(error.violations, '/data')),
      );
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
      return BoundaryErr<CreateParams<T>>(
        targetType: 'CreateParams',
        violations: violations,
      );
    }
    return BoundaryOk<CreateParams<T>>(
      CreateParams.fromTrusted(data: _data!, params: _params),
    );
  }

  Map<String, Object?> toWire(Map<String, Object?> Function(T value) encodeT) {
    final map = <String, Object?>{};
    map['data'] = encodeT(this.data);
    final _params = this.params;
    if (_params != null) {
      map['params'] = _params;
    }
    return map;
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

