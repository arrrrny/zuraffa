// dart format off
part of '../../../../src/core/params/toggle_params.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class ToggleParams<I extends Object, F> implements ZorphyValueBase {
  ToggleParams.fromTrusted({
    required this.id,
    required this.field,
    this.value,
    Map<String, dynamic>? params,
  }) : params = params == null ? null : Map<String, dynamic>.of(params);

  final I id;

  final F field;

  final Object? value;

  final Map<String, dynamic>? params;

  ToggleParams<I, F> copyWith({
    I? id,
    F? field,
    Object? value = _sentinel,
    Object? params = _sentinel,
  }) {
    return ToggleParams<I, F>.fromTrusted(
      id: id ?? this.id,
      field: field ?? this.field,
      value: identical(value, _sentinel) ? this.value : value as Object?,
      params: identical(params, _sentinel)
          ? this.params
          : params as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ToggleParams &&
        this.id == other.id &&
        this.field == other.field &&
        this.value == other.value &&
        ToggleParams._zorphyCollectionEquals(this.params, other.params);
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    field,
    value,
    ToggleParams._zorphyCollectionHash(params),
  ]);

  @override
  String toString() =>
      'ToggleParams(id: $id, field: $field, value: $value, params: $params)';

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

  static ZorphyBoundaryResult<ToggleParams<I, F>> fromWire<I extends Object, F>(
    Map<String, Object?> raw,
    ZorphyBoundaryResult<I> Function(Map<String, Object?> raw) decodeI,
    ZorphyBoundaryResult<F> Function(Map<String, Object?> raw) decodeF,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_id = raw['id'];
    I? _id;
    final map_id = _boundaryObject(raw_id, '/id', violations);
    if (map_id != null) {
      decodeI(map_id).fold(
        (value) {
          _id = value;
        },
        (error) => violations.addAll(_boundaryPrefix(error.violations, '/id')),
      );
    }
    final Object? raw_field = raw['field'];
    F? _field;
    final map_field = _boundaryObject(raw_field, '/field', violations);
    if (map_field != null) {
      decodeF(map_field).fold(
        (value) {
          _field = value;
        },
        (error) =>
            violations.addAll(_boundaryPrefix(error.violations, '/field')),
      );
    }
    final Object? raw_value = raw['value'];
    Object? _value;
    if (raw_value != null) {
      _value = _boundaryAs<Object>(raw_value, '/value', violations);
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
      return BoundaryErr<ToggleParams<I, F>>(
        targetType: 'ToggleParams',
        violations: violations,
      );
    }
    return BoundaryOk<ToggleParams<I, F>>(
      ToggleParams.fromTrusted(
        id: _id!,
        field: _field!,
        value: _value,
        params: _params,
      ),
    );
  }

  Map<String, Object?> toWire(
    Map<String, Object?> Function(I value) encodeI,
    Map<String, Object?> Function(F value) encodeF,
  ) {
    final map = <String, Object?>{};
    map['id'] = encodeI(this.id);
    map['field'] = encodeF(this.field);
    final _value = this.value;
    if (_value != null) {
      map['value'] = _value;
    }
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

