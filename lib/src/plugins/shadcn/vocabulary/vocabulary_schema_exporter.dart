/// Versioned, diff-stable UI vocabulary schema export (spec 024 FR-001 /
/// FR-005, SC-001, SC-004).
///
/// The export is a JSON object with:
/// - `schemaVersion` (semver)
/// - `components` — self-contained JSON-Schema-style definitions per node
///   type (props, enums, children constraints)
/// - `structuralRules` — `maxDepth` / `maxNodes` tree caps
/// - `styleTokens` — the canonical token enum
/// - `actionIdGrammar` — pattern + description
/// - `nestingRules` — per-parent allowed child types
///
/// Determinism: keys are emitted sorted with no timestamps, so consecutive
/// exports with an unchanged vocabulary are byte-identical.
library;

import 'dart:convert';

import 'ui_node_registry.dart';

class VocabularySchemaExporter {
  VocabularySchemaExporter(this.registry, {this.schemaVersion = '1.0.0'});

  final NodeRegistry registry;

  /// Semver-compatible version of the exported vocabulary.
  final String schemaVersion;

  /// The action-ID grammar: dotted lowercase identifiers, e.g.
  /// `product.select_offer`.
  static const String actionIdPattern =
      r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$';

  /// Exports the vocabulary as a JSON-compatible map.
  Map<String, dynamic> export() {
    final components = <String, dynamic>{};
    final nestingRules = <String, dynamic>{};

    for (final definition in registry.sortedDefinitions) {
      components[definition.name] = _componentDefinition(definition);
      final allowed = definition.children.allowedChildTypes;
      if (allowed != null) {
        nestingRules[definition.name] = {
          'allowedChildren': allowed,
          if (definition.children.max != null)
            'maxChildren': definition.children.max,
          if (definition.children.min != null)
            'minChildren': definition.children.min,
        };
      }
    }

    return _sortedMap({
      'schemaVersion': schemaVersion,
      'components': _sortedMap(components),
      'structuralRules': _sortedMap({
        'maxDepth': registry.maxDepth,
        'maxNodes': registry.maxNodes,
      }),
      'styleTokens': registry.styleTokens,
      'actionIdGrammar': _sortedMap({
        'pattern': actionIdPattern,
        'description': 'Dotted lowercase identifiers, e.g. '
            "'product.select_offer'.",
      }),
      if (nestingRules.isNotEmpty) 'nestingRules': _sortedMap(nestingRules),
    });
  }

  /// Exports the vocabulary as a pretty-printed JSON string (diff-stable).
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(export());
  }

  Map<String, dynamic> _componentDefinition(UiNodeDefinition definition) {
    final properties = <String, dynamic>{};
    final required = <String>[];
    for (final prop
        in definition.props.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name))) {
      properties[prop.name] = prop.toJson();
      if (prop.required) required.add(prop.name);
    }
    return _sortedMap({
      'type': 'object',
      'category': definition.category,
      'properties': _sortedMap(properties),
      'required': required,
      'children': definition.children.toJson(),
      if (definition.isComposite) 'composite': true,
    });
  }

  static Map<String, dynamic> _sortedMap(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    return {for (final key in keys) key: map[key]};
  }
}

/// Derives the agent `ui.render` tool input schema directly from an
/// exported vocabulary artifact (SC-004 — "consumed as-is ... with no
/// manual transformation").
///
/// The produced schema describes the tool's `tree` parameter: a recursive
/// node object whose `type` enum, `styleToken` enum, and `actionId`
/// pattern come straight from the export.
abstract final class UiRenderInputSchema {
  /// Builds `{'tree': <node-schema>}` from [export].
  static Map<String, dynamic> fromExport(Map<String, dynamic> export) {
    final components = export['components'] as Map<String, dynamic>;
    final tokens = (export['styleTokens'] as List).cast<String>();
    final grammar = export['actionIdGrammar'] as Map<String, dynamic>;
    final rules = export['structuralRules'] as Map<String, dynamic>;

    final nodeSchema = <String, dynamic>{
      'type': 'object',
      'properties': {
        'type': {
          'type': 'string',
          'enum': components.keys.toList(),
        },
        'props': {'type': 'object'},
        'children': {
          'type': 'array',
          'items': {'\$ref': '#/tree/node'},
          'maxItems': rules['maxNodes'],
        },
        'styleToken': {'type': 'string', 'enum': tokens},
        'actionId': {
          'type': 'string',
          'pattern': grammar['pattern'],
        },
      },
      'required': ['type'],
    };

    return {
      'tree': nodeSchema,
    };
  }

  /// Lightweight structural check of [tree] against a derived [schema]
  /// (from [fromExport]). Returns null when the tree is acceptable, or a
  /// human-readable violation message.
  static String? validateTree(
    Map<String, dynamic> schema,
    Map<String, dynamic> tree,
  ) {
    final nodeSchema = schema['tree'] as Map<String, dynamic>;
    final typeSchema = (nodeSchema['properties']
        as Map<String, dynamic>)['type'] as Map<String, dynamic>;
    final allowedTypes = (typeSchema['enum'] as List).cast<String>();

    String? checkNode(Map<String, dynamic> node, int depth) {
      final type = node['type'];
      if (type is! String || !allowedTypes.contains(type)) {
        return 'Unknown node type "$type" — allowed: '
            '${allowedTypes.take(8).join(", ")}...';
      }
      final tokenSchema = (nodeSchema['properties']
          as Map<String, dynamic>)['styleToken'] as Map<String, dynamic>?;
      final styleToken = node['styleToken'];
      if (tokenSchema != null &&
          styleToken is String &&
          !(tokenSchema['enum'] as List).contains(styleToken)) {
        return 'Invalid styleToken "$styleToken".';
      }
      final children = node['children'];
      if (children is List) {
        final maxDepth =
            ((schema['tree'] as Map)['maxDepth'] as int?) ?? 64;
        if (depth >= maxDepth) {
          return 'Tree exceeds maxDepth $maxDepth.';
        }
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            final violation = checkNode(child, depth + 1);
            if (violation != null) return violation;
          }
        }
      }
      return null;
    }

    return checkNode(tree, 0);
  }
}
