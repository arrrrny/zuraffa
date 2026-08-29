import 'dart:async';
import 'dart:io';

import '../../../core/plugin_system/capability.dart';
import '../shadcn_plugin.dart';
import '../vocabulary/ui_node_registry.dart';
import '../vocabulary/vocabulary_schema_exporter.dart';

/// MCP-discoverable capability exposing the UI vocabulary schema export
/// (spec 024 FR-006).
///
/// Executing with `{'projectRoot': <path>}` returns the exported schema
/// (including project composites) so MCP clients and agent tools can
/// discover the vocabulary without shell access.
class UiVocabularyExportCapability implements ZuraffaCapability {
  UiVocabularyExportCapability(this.plugin);

  final ShadcnPlugin plugin;

  @override
  String get name => 'ui.schema.export';

  @override
  String get description =>
      'Export the shadcn plugin UI component vocabulary as a versioned, '
      'diff-stable JSON Schema (components, props, enums, children '
      'constraints, structural rules, style tokens, action-ID grammar).';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'projectRoot': {
            'type': 'string',
            'description': 'Project root to load composites from '
                '(defaults to the current directory).',
          },
          'schemaVersion': {
            'type': 'string',
            'description': 'Version stamp for the export (defaults to the '
                'registry version).',
          },
        },
      };

  @override
  JsonSchema get outputSchema => {
        'type': 'object',
        'properties': {
          'schema': {
            'type': 'object',
            'description': 'The exported UI vocabulary schema.',
          },
        },
      };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    return EffectReport(
      planId: 'ui-schema-export',
      pluginId: plugin.id,
      capabilityName: name,
      args: args,
      changes: const [],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot']?.toString() ?? Directory.current.path;
    final registry = NodeRegistry.load(projectRoot: projectRoot);
    final exporter = VocabularySchemaExporter(
      registry,
      schemaVersion: args['schemaVersion']?.toString() ?? '1.0.0',
    );
    return ExecutionResult(
      success: true,
      data: {'schema': exporter.export()},
    );
  }
}
