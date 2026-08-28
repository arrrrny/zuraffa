/// `zfa make --with=tui` capability that generates list/detail TUI screens
/// for an entity (FR-011, SC-005).
///
/// Invoked by the Zuraffa generator pipeline when `--with=tui` is present.
/// Emits `<Entity>ListScreen` and `<Entity>DetailScreen` Dart source files
/// wired to the entity's existing use cases — no manual wiring required.
library;

import '../../../../core/plugin_system/capability.dart';
import '../../../../models/generated_file.dart';
import '../../../../models/generator_config.dart';
import '../tui_screen_generator.dart';

/// Capability that emits list/detail TUI screens for an entity.
///
/// Discovered via [ZuraffaTuiPlugin.capabilities]; invoked by `zfa make
/// --with=tui`. The emitted screens use only `package:zuraffa/...` and
/// `package:nocterm/...` imports — never `package:flutter` (FR-012).
class CreateTuiScreensCapability implements ZuraffaCapability {
  CreateTuiScreensCapability({
    required this.generator,
    required this.outputDir,
  });

  final TuiScreenGenerator generator;
  final String outputDir;

  @override
  String get name => 'create-tui-screens';

  @override
  String get description =>
      'Generate list/detail TUI screens for an entity, wired to its '
      'existing use cases (FR-011, SC-005). Pure-Dart — no Flutter.';

  @override
  JsonSchema get inputSchema => {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Entity name (e.g. Product)',
          },
          'fields': {
            'type': 'array',
            'description': 'Entity fields',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'type': {'type': 'string'},
              },
            },
          },
          'useCases': {
            'type': 'array',
            'description': 'Use cases available for binding (get, getList)',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'returnsType': {'type': 'string'},
                'isStream': {'type': 'boolean', 'default': false},
                'paramsType': {'type': 'string'},
              },
            },
          },
          'repositoryName': {
            'type': 'string',
            'description': 'Repository class name (defaults to '
                '<Entity>Repository)',
          },
        },
        'required': ['name', 'fields', 'useCases'],
      };

  @override
  JsonSchema get outputSchema => {
        'type': 'object',
        'properties': {
          'files': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'path': {'type': 'string'},
                'content': {'type': 'string'},
              },
            },
          },
        },
      };

  /// Generates the list + detail screen files for the given entity input.
  ///
  /// Public so the plugin can be invoked from outside `execute` (e.g. from
  /// tests, or from the generator pipeline's direct file-write path).
  List<GeneratedFile> generateFiles(Map<String, dynamic> input) {
    final entity = TuiEntitySpec(
      name: input['name'] as String,
      fields: (input['fields'] as List)
          .map((f) => TuiFieldSpec(
                name: (f as Map)['name'] as String,
                type: f['type'] as String,
              ))
          .toList(),
      useCases: (input['useCases'] as List)
          .map((u) => TuiUseCaseSpec(
                name: (u as Map)['name'] as String,
                returnsType: u['returnsType'] as String,
                isStream: (u['isStream'] as bool?) ?? false,
                paramsType: u['paramsType'] as String?,
              ))
          .toList(),
      repositoryName: input['repositoryName'] as String?,
    );

    final listSource = generator.generateListScreen(entity);
    final detailSource = generator.generateDetailScreen(entity);

    final entitySnake = entity.name.toLowerCase();
    return [
      GeneratedFile(
        path: '$outputDir/presentation/tui/${entitySnake}_list_screen.dart',
        type: 'tui_list_screen',
        action: 'create',
        content: listSource,
      ),
      GeneratedFile(
        path: '$outputDir/presentation/tui/${entitySnake}_detail_screen.dart',
        type: 'tui_detail_screen',
        action: 'create',
        content: detailSource,
      ),
    ];
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final files = generateFiles(args);
    return ExecutionResult(
      success: true,
      files: files.map((f) => f.path).toList(),
      data: {
        'generated_files': files
            .map((f) => {'path': f.path, 'content': f.content})
            .toList(),
      },
    );
  }

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final files = generateFiles(args);
    return EffectReport(
      planId: 'tui-screens-${DateTime.now().microsecondsSinceEpoch}',
      pluginId: 'tui',
      capabilityName: name,
      args: args,
      changes: files
          .map((f) => Effect(
                file: f.path,
                action: f.action,
                diff: 'Generate ${f.type}',
              ))
          .toList(),
      isValid: true,
    );
  }

  /// Whether the capability can run given the [config].
  ///
  /// The capability can always run if there's an entity name in the config.
  bool canExecute(GeneratorConfig config) {
    return config.name.isNotEmpty;
  }
}
