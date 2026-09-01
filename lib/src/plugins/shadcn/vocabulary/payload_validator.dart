/// UI payload validation with precise, per-category diagnostics (spec 024
/// FR-003, SC-003).
///
/// Categories: `unknownNode`, `badToken`, `rawColor`, `depthCap`,
/// `countCap`, `invalidAction`, `invalidNesting`. All violations are
/// reported in a single pass (never fail-fast) with the offending node
/// name and its tree path.
library;

import 'dart:convert';
import 'dart:io';

import 'ui_node_registry.dart';
import 'vocabulary_schema_exporter.dart';

enum ValidationErrorCategory {
  unknownNode,
  badToken,
  rawColor,
  depthCap,
  countCap,
  invalidAction,
  invalidNesting,
}

/// One diagnostic: category + actionable message + tree path.
class UiPayloadError {
  const UiPayloadError(this.kind, this.message, this.path);

  final ValidationErrorCategory kind;
  final String message;

  /// Path of the offending node from the root, e.g.
  /// `card > text > ghost_node`.
  final String path;

  @override
  String toString() => '[${kind.name}] $path: $message';
}

class UiPayloadValidationResult {
  const UiPayloadValidationResult({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
    this.payloadVersion,
    this.schemaVersion,
  });

  final bool valid;
  final List<UiPayloadError> errors;
  final List<String> warnings;
  final String? payloadVersion;
  final String? schemaVersion;
}

/// Raised when the payload file cannot be parsed (Edge Cases).
class UiPayloadParseException implements Exception {
  UiPayloadParseException(this.message);
  final String message;

  @override
  String toString() => 'UiPayloadParseException: $message';
}

class UiPayloadValidator {
  UiPayloadValidator(this.registry, {this.schemaVersion = '1.0.0'});

  final NodeRegistry registry;

  /// The vocabulary version this validator checks against.
  final String schemaVersion;

  static final RegExp _rawColorPattern = RegExp(
    r'^(#[0-9a-fA-F]{3,8}|rgba?\(.*\)|hsla?\(.*\)|Colors\.[a-zA-Z]+|0x[0-9a-fA-F]{8})$',
  );

  /// Validates a payload map: `{'tree': <node>}` or a bare node.
  UiPayloadValidationResult validate(Map<String, dynamic> payload) {
    final errors = <UiPayloadError>[];
    final warnings = <String>[];

    String? payloadVersion;
    Map<String, dynamic> tree;
    if (payload.containsKey('tree') && payload['tree'] is Map) {
      // The payload is user-supplied JSON: a non-string schemaVersion must
      // not blow up the validator with an uncaught CastError.
      final declared = payload['schemaVersion'];
      payloadVersion = declared is String ? declared : null;
      tree = (payload['tree'] as Map).cast<String, dynamic>();
    } else {
      tree = payload;
    }

    if (payloadVersion != null && payloadVersion != schemaVersion) {
      warnings.add(
        'Version pin mismatch: payload declares schemaVersion '
        '"$payloadVersion" but the vocabulary is "$schemaVersion". '
        'Re-export with `zfa ui schema` and migrate the payload.',
      );
    }

    final count = _countNodes(tree);
    if (count > registry.maxNodes) {
      errors.add(
        UiPayloadError(
          ValidationErrorCategory.countCap,
          'Tree has $count nodes; the maximum allowed is '
          '${registry.maxNodes}.',
          _pathOf(tree),
        ),
      );
    }

    _validateNode(tree, [], errors);

    return UiPayloadValidationResult(
      valid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      payloadVersion: payloadVersion,
      schemaVersion: schemaVersion,
    );
  }

  /// Validates a payload file. Throws [UiPayloadParseException] when the
  /// file is not valid JSON (with the file path in the message).
  UiPayloadValidationResult validateFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw UiPayloadParseException('Payload file not found: $path');
    }
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(file.readAsStringSync());
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('payload root is not a JSON object');
      }
      decoded = parsed;
    } on FormatException catch (e) {
      throw UiPayloadParseException(
        'Payload file $path is not valid JSON: ${e.message}',
      );
    }
    return validate(decoded);
  }

  void _validateNode(
    Map<String, dynamic> node,
    List<String> path,
    List<UiPayloadError> errors,
  ) {
    final type = node['type'];
    final typePath = [...path, type is String ? type : '<missing type>'];

    // Unknown node (US-3 scenario 2).
    if (type is! String || !registry.contains(type)) {
      errors.add(
        UiPayloadError(
          ValidationErrorCategory.unknownNode,
          'Node type "$type" is not in the UI vocabulary. Known types: '
          '${registry.allNames.take(8).join(", ")}...',
          typePath.join(' > '),
        ),
      );
      // Still walk children so every violation surfaces in one pass.
      _walkChildren(node, typePath, errors);
      return;
    }

    final definition = registry.definition(type)!;

    // Style token (badToken + rawColor).
    final styleToken = node['styleToken'];
    if (styleToken is String) {
      if (registry.styleTokens.contains(styleToken)) {
        // good token
      } else if (_rawColorPattern.hasMatch(styleToken)) {
        errors.add(
          UiPayloadError(
            ValidationErrorCategory.rawColor,
            'Raw color value "$styleToken" is not allowed — reference a style '
            'token instead (e.g. "${registry.styleTokens.first}").',
            typePath.join(' > '),
          ),
        );
      } else {
        errors.add(
          UiPayloadError(
            ValidationErrorCategory.badToken,
            'Style token "$styleToken" is not in the allowed token set '
            '(${registry.styleTokens.join(", ")}).',
            typePath.join(' > '),
          ),
        );
      }
    }

    // Action ID grammar (US-3 scenario 5).
    final actionId = node['actionId'];
    if (actionId != null &&
        (actionId is! String ||
            !RegExp(VocabularySchemaExporter.actionIdPattern)
                .hasMatch(actionId))) {
      errors.add(
        UiPayloadError(
          ValidationErrorCategory.invalidAction,
          'Action id "$actionId" does not match the action-ID grammar '
          '(${VocabularySchemaExporter.actionIdPattern} — dotted lowercase '
          'identifiers, e.g. "product.select_offer").',
          typePath.join(' > '),
        ),
      );
    }

    // Prop values — raw color detection (US-3 scenario 4).
    final props = node['props'];
    if (props is Map<String, dynamic>) {
      for (final entry in props.entries) {
        final value = entry.value;
        if (value is String && _rawColorPattern.hasMatch(value)) {
          errors.add(
            UiPayloadError(
              ValidationErrorCategory.rawColor,
              'Raw color value "$value" in prop "${entry.key}" is not '
              'allowed — reference a style token instead (e.g. '
              '"${registry.styleTokens.first}").',
              typePath.join(' > '),
            ),
          );
        }
      }
      // Enum prop validation against the definition.
      for (final prop in definition.props.values) {
        if (prop.enumValues == null) continue;
        final value = props[prop.name];
        if (value != null &&
            value is String &&
            !prop.enumValues!.contains(value)) {
          errors.add(
            UiPayloadError(
              ValidationErrorCategory.badToken,
              'Prop "${prop.name}" value "$value" is not one of '
              '${prop.enumValues!.join(", ")}.',
              typePath.join(' > '),
            ),
          );
        }
      }
    }

    // Depth cap — checked per node, outside the children block: a leaf that
    // sits too deep must still be reported, and a node exactly at maxDepth
    // that merely carries an empty `children` list must not be.
    if (typePath.length > registry.maxDepth) {
      errors.add(
        UiPayloadError(
          ValidationErrorCategory.depthCap,
          'Tree depth exceeds the maximum of ${registry.maxDepth} at this '
          'node.',
          typePath.join(' > '),
        ),
      );
    }

    // Children constraints (invalidNesting, US-3 scenario 3).
    final children = node['children'];
    if (children is List) {
      final childCount = children.length;
      final constraint = definition.children;
      if (constraint.max != null && childCount > constraint.max!) {
        errors.add(
          UiPayloadError(
            ValidationErrorCategory.invalidNesting,
            'Node "$type" has $childCount children; at most ${constraint.max} '
            'are allowed.',
            typePath.join(' > '),
          ),
        );
      }
      if (constraint.min != null && childCount < constraint.min!) {
        errors.add(
          UiPayloadError(
            ValidationErrorCategory.invalidNesting,
            'Node "$type" has $childCount children; at least ${constraint.min} '
            'are required.',
            typePath.join(' > '),
          ),
        );
      }
      if (constraint.allowedChildTypes != null) {
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            final childType = child['type'];
            if (childType is String &&
                !constraint.allowedChildTypes!.contains(childType)) {
              errors.add(
                UiPayloadError(
                  ValidationErrorCategory.invalidNesting,
                  'Node "$type" only allows children of type '
                      '${constraint.allowedChildTypes!.join(", ")}, but found '
                      '"$childType".',
                  '${typePath.join(" > ")} > $childType',
                ),
              );
            }
          }
        }
      }

      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _validateNode(child, typePath, errors);
        }
      }
    }
  }

  void _walkChildren(
    Map<String, dynamic> node,
    List<String> path,
    List<UiPayloadError> errors,
  ) {
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _validateNode(child, path, errors);
        }
      }
    }
  }

  int _countNodes(Map<String, dynamic> node) {
    var count = 1;
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          count += _countNodes(child);
        }
      }
    }
    return count;
  }

  String _pathOf(Map<String, dynamic> node) =>
      node['type']?.toString() ?? '<root>';
}
