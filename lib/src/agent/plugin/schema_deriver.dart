/// Dart type to JSON Schema derivation across the full type matrix (FR-006, SC-002).
///
/// The schema deriver operates on string type references (since
/// generated code emits string-named types) and produces JSON Schema
/// (draft-07 subset) shapes. It handles:
///   - Primitives: `String`, `int`, `double`, `num`, `bool`
///   - `DateTime` (mapped to `{"type":"string","format":"date-time"}`)
///   - `List<T>` (array)
///   - `Map<String, V>` (object with `additionalProperties`)
///   - Nullable `T?`
///   - Enums (best-effort: caller may pass known values)
///   - Nested entities (caller provides a field map; recursive descent
///     with cycle guard)
///   - `SignalResult<T>` unwrapping
///   - Unresolvable types → open-object with description
library;

import 'dart:convert';

/// A field of a nested entity, for inlined object schema derivation.
class EntityFieldSpec {
  final String name;
  final String typeRef;
  final bool isRequired;

  const EntityFieldSpec({
    required this.name,
    required this.typeRef,
    required this.isRequired,
  });
}

// The EntitySpec wrapper has been removed in favor of a flat
// `Map<String, List<EntityFieldSpec>>` keyed by entity name. Tests and
// callers already supply the field list directly; the wrapper duplicated
// the key with no behavioral benefit.

/// Schema deriver for generated MCP tool wrappers.
class SchemaDeriver {
  /// Map of entity name → field list, for nested-entity resolution.
  /// The caller populates this from the introspector's results.
  final Map<String, List<EntityFieldSpec>> knownEntities;

  /// Map of enum name → list of allowed values.
  final Map<String, List<String>> knownEnums;

  const SchemaDeriver({
    Map<String, List<EntityFieldSpec>>? knownEntities,
    Map<String, List<String>>? knownEnums,
  }) : knownEntities = const {},
       knownEnums = const {};

  const SchemaDeriver.withEntities({
    required this.knownEntities,
    required this.knownEnums,
  });

  /// Derives a JSON Schema for [typeRef]. [visiting] is used internally
  /// for cycle detection on nested entities.
  Map<String, dynamic> derive(String typeRef, {Set<String>? visiting}) {
    final seen = visiting ?? <String>{};
    return _derive(typeRef, seen);
  }

  Map<String, dynamic> _derive(String typeRef, Set<String> visiting) {
    final t = typeRef.trim();

    // Unwrap SignalResult<T> → schema of T.
    if (t.startsWith('SignalResult<') && t.endsWith('>')) {
      final inner = t.substring('SignalResult<'.length, t.length - 1);
      return _derive(inner, visiting);
    }

    // Unwrap Future<T> → schema of T (usecase return types are async).
    if (t.startsWith('Future<') && t.endsWith('>')) {
      final inner = t.substring('Future<'.length, t.length - 1);
      return _derive(inner, visiting);
    }

    // Unwrap Result<T> or Result<T, E> → schema of T.
    if (t.startsWith('Result<') && t.endsWith('>')) {
      final inner = t.substring('Result<'.length, t.length - 1);
      final firstArg = _firstTypeArg(inner);
      return _derive(firstArg, visiting);
    }

    // Nullable: ends with ?
    if (t.endsWith('?')) {
      final inner = t.substring(0, t.length - 1).trim();
      final innerSchema = _derive(inner, visiting);
      return {...innerSchema, 'nullable': true};
    }

    // List<T>
    if (t.startsWith('List<') && t.endsWith('>')) {
      final inner = t.substring('List<'.length, t.length - 1);
      return {'type': 'array', 'items': _derive(inner, visiting)};
    }

    // Map<K, V> — assume K is String (the common case for JSON).
    if (t.startsWith('Map<') && t.endsWith('>')) {
      final inner = t.substring('Map<'.length, t.length - 1);
      final parts = _splitTopLevelCommas(inner);
      final vType = parts.length >= 2 ? parts[1].trim() : 'dynamic';
      return {
        'type': 'object',
        'additionalProperties': _derive(vType, visiting),
      };
    }

    // Primitives
    switch (t) {
      case 'String':
        return {'type': 'string'};
      case 'int':
        return {'type': 'integer'};
      case 'double':
      case 'num':
        return {'type': 'number'};
      case 'bool':
        return {'type': 'boolean'};
      case 'dynamic':
        return {'type': 'object'};
      case 'DateTime':
        return {'type': 'string', 'format': 'date-time'};
      case 'void':
      case 'Null':
        return {'type': 'null'};
    }

    // Enums
    final enumValues = knownEnums[t];
    if (enumValues != null) {
      return {'type': 'string', 'enum': enumValues};
    }

    // Nested entities (with cycle guard).
    final entityFields = knownEntities[t];
    if (entityFields != null) {
      if (visiting.contains(t)) {
        // Cycle: emit $ref.
        return {'\$ref': '#/definitions/$t'};
      }
      final nextVisiting = {...visiting, t};
      final properties = <String, dynamic>{};
      final required = <String>[];
      for (final f in entityFields) {
        properties[f.name] = _derive(f.typeRef, nextVisiting);
        if (f.isRequired) required.add(f.name);
      }
      return {
        'type': 'object',
        'properties': properties,
        if (required.isNotEmpty) 'required': required,
      };
    }

    // Unresolvable type → open-object with documentation.
    return {
      'type': 'object',
      'description': 'Unresolvable type $t — schema inferred as open object',
    };
  }

  /// Splits a comma-separated type-args string on top-level commas
  /// (ignoring commas inside nested generics).
  static List<String> _splitTopLevelCommas(String s) {
    final parts = <String>[];
    var depth = 0;
    final buf = StringBuffer();
    for (final c in s.runes) {
      final ch = String.fromCharCode(c);
      if (ch == '<' || ch == '[' || ch == '(') {
        depth++;
        buf.write(ch);
      } else if (ch == '>' || ch == ']' || ch == ')') {
        depth--;
        buf.write(ch);
      } else if (ch == ',' && depth == 0) {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }

  /// Returns the first type argument from a string like `T, E`.
  static String _firstTypeArg(String s) {
    final parts = _splitTopLevelCommas(s);
    return parts.isEmpty ? 'dynamic' : parts[0].trim();
  }
}

/// Helper: encodes a schema map to a pretty JSON string for embedding
/// in emitted tool wrapper source.
String schemaToSourceLiteral(Map<String, dynamic> schema) {
  const encoder = JsonEncoder.withIndent('  ');
  final json = encoder.convert(schema);
  // Convert pretty JSON to a Dart multi-line string literal.
  return "'''$json'''";
}
