/// ZAP structural validator (spec 071, issue #809, FR-007).
///
/// A deliberately small draft-07 SUBSET engine — exactly the keywords the
/// ZAP schemas use: `type`, `enum`, `required`, `properties`, `items`,
/// `additionalProperties`, `minLength`, `minItems`, `uniqueItems`,
/// `pattern`, `minimum`, `maximum`. Every rejection carries the JSON PATH
/// of the offending value, so a hallucinated tool call is rejected with
/// `steps[0].phase: must be one of red|green|refactor|verify` — not with
/// a shrug.
///
/// Third-party path: `validate(message, schema: <schema from the published
/// files>)` validates against any schema limited to the same subset.
library;

import 'zap_protocol.dart';
import 'zap_schema.dart';

/// One validation failure: where ([path]) and why ([message]).
class ZapValidationIssue {
  const ZapValidationIssue({required this.path, required this.message});

  /// JSON path of the offending value (`steps[0].phase`, `` for root).
  final String path;

  /// Human-readable reason, naming the allowed shape when there is one.
  final String message;

  @override
  String toString() => '$path: $message';
}

/// The outcome of validating one document.
class ZapValidationResult {
  const ZapValidationResult({required this.issues});

  factory ZapValidationResult.ok() => const ZapValidationResult(issues: []);

  final List<ZapValidationIssue> issues;

  bool get ok => issues.isEmpty;

  @override
  String toString() =>
      ok ? 'valid' : issues.map((i) => i.toString()).join('; ');
}

/// Validates raw ZAP documents against the ZAP schemas.
abstract final class ZapValidator {
  /// Validates [document] (already JSON-decoded) against the schema for
  /// its `type` field, or against [schema] when given.
  ///
  /// Never throws — structural problems are DATA ([issues]), not
  /// exceptions; the host turns them into `error` envelopes.
  static ZapValidationResult validate(
    Map<String, Object?> document, {
    Map<String, Object?>? schema,
  }) {
    final resolved = schema ?? _schemaFor(document);
    if (resolved == null) {
      return ZapValidationResult(
        issues: [
          ZapValidationIssue(
            path: 'type',
            message:
                'unknown message type '
                '"${document['type']}"; must be one of '
                '${zapMessageTypes.join('|')}',
          ),
        ],
      );
    }
    return _validateValue(document, resolved, '');
  }

  /// Validates an arbitrary decoded [value] against [schema] — the
  /// third-party entry for roots that are not message objects.
  static ZapValidationResult validateWith(
    Object? value,
    Map<String, Object?> schema,
  ) => _validateValue(value, schema, '');

  /// Validates a raw (not yet decoded) [value] as a ZAP message root:
  /// rejects non-objects before schema dispatch.
  static ZapValidationResult validateRaw(Object? value) {
    if (value is! Map) {
      return ZapValidationResult(
        issues: [
          ZapValidationIssue(
            path: '',
            message:
                'a ZAP message is a JSON object; got '
                '${value == null ? 'null' : value.runtimeType}',
          ),
        ],
      );
    }
    return validate(value.cast<String, Object?>());
  }

  static Map<String, Object?>? _schemaFor(Map<String, Object?> document) {
    final type = document['type'];
    if (type is! String) return null;
    return ZapSchema.all[type];
  }

  // ----------------------------------------------------------------
  // The draft-07 subset engine
  // ----------------------------------------------------------------

  static ZapValidationResult _validateValue(
    Object? value,
    Map<String, Object?> schema,
    String path,
  ) {
    final issues = <ZapValidationIssue>[];
    _check(value, schema, path, issues);
    return ZapValidationResult(issues: issues);
  }

  static void _check(
    Object? value,
    Map<String, Object?> schema,
    String path,
    List<ZapValidationIssue> issues,
  ) {
    // `type`
    final type = schema['type'];
    if (type is String && !_matchesType(value, type)) {
      issues.add(
        ZapValidationIssue(
          path: path,
          message:
              'must be of type $type; got '
              '${value == null ? 'null' : value.runtimeType}',
        ),
      );
      return; // deeper checks on a wrong-typed value add noise
    }

    // `enum`
    final allowed = schema['enum'];
    if (allowed is List && !allowed.contains(value)) {
      issues.add(
        ZapValidationIssue(
          path: path,
          message: 'must be one of ${allowed.join('|')}',
        ),
      );
    }

    // numeric bounds
    if (value is num) {
      final minimum = schema['minimum'];
      if (minimum is num && value < minimum) {
        issues.add(
          ZapValidationIssue(
            path: path,
            message: 'must be >= $minimum; got $value',
          ),
        );
      }
      final maximum = schema['maximum'];
      if (maximum is num && value > maximum) {
        issues.add(
          ZapValidationIssue(
            path: path,
            message: 'must be <= $maximum; got $value',
          ),
        );
      }
    }

    // string shape
    if (value is String) {
      final minLength = schema['minLength'];
      if (minLength is int && value.length < minLength) {
        issues.add(
          ZapValidationIssue(
            path: path,
            message:
                'must be at least $minLength character(s); got '
                '${value.length}',
          ),
        );
      }
      final pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) {
        issues.add(
          ZapValidationIssue(
            path: path,
            message: 'must match ${pattern.replaceAll('\\', '')}',
          ),
        );
      }
    }

    // array shape
    if (value is List) {
      final minItems = schema['minItems'];
      if (minItems is int && value.length < minItems) {
        issues.add(
          ZapValidationIssue(
            path: path,
            message:
                'must have at least $minItems item(s); got '
                '${value.length}',
          ),
        );
      }
      if (schema['uniqueItems'] == true) {
        final seen = <String>{};
        for (final item in value) {
          // JSON-scalar identity is enough for allowlists (strings).
          final key = item is String ? item : item.toString();
          if (!seen.add(key)) {
            issues.add(
              ZapValidationIssue(
                path: path,
                message:
                    'items must be unique; "$item" appears more than '
                    'once',
              ),
            );
            break;
          }
        }
      }
      final items = schema['items'];
      if (items is Map<String, Object?>) {
        for (var i = 0; i < value.length; i++) {
          // Array indexes attach directly: `steps[0].phase`, not
          // `steps.[0].phase`.
          _check(value[i], items, '$path[$i]', issues);
        }
      }
    }

    // object shape
    if (value is Map) {
      final required = schema['required'];
      if (required is List) {
        for (final field in required) {
          if (field is String && !value.containsKey(field)) {
            issues.add(
              ZapValidationIssue(
                path: _join(path, field),
                message: 'required field is missing',
              ),
            );
          }
        }
      }
      final properties = schema['properties'];
      final additional = schema['additionalProperties'];
      for (final entry in value.entries) {
        final fieldSchema = properties is Map<String, Object?>
            ? properties[entry.key]
            : null;
        if (fieldSchema is Map<String, Object?>) {
          _check(entry.value, fieldSchema, _join(path, entry.key), issues);
        } else if (additional == false) {
          issues.add(
            ZapValidationIssue(
              path: _join(path, entry.key),
              message:
                  'unknown field — the envelope is closed '
                  '(additionalProperties: false)',
            ),
          );
        }
      }
    }
  }

  /// draft-07 `type` matching, with the JSON integer/number nuance.
  static bool _matchesType(Object? value, String type) {
    switch (type) {
      case 'object':
        return value is Map;
      case 'array':
        return value is List;
      case 'string':
        return value is String;
      case 'boolean':
        return value is bool;
      case 'integer':
        // isFinite guards double.infinity/NaN (e.g. jsonDecode of
        // `1e999`): toInt() would throw, and this engine never throws.
        return value is int ||
            (value is num && value.isFinite && value.toInt() == value);
      case 'number':
        return value is num;
      case 'null':
        return value == null;
      default:
        return true; // unknown type keywords are not this engine's problem
    }
  }

  static String _join(String path, String segment) =>
      path.isEmpty ? segment : '$path.$segment';
}
