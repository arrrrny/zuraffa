import 'package:args/command_runner.dart';

import '../../commands/state_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/state_builder.dart';
import 'capabilities/create_state_capability.dart';

/// Manages UI state class generation for the presentation layer.
class StatePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final StateBuilder stateBuilder;

  StatePlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    stateBuilder = StateBuilder(outputDir: outputDir, options: options);
  }

  @override
  List<ZuraffaCapability> get capabilities => [CreateStateCapability(this)];

  @override
  Command createCommand() => StateCommand(this);

  @override
  String get id => 'state';

  @override
  String get name => 'State Plugin';

  @override
  String get version => '1.0.0';

  /// Spec 1126 (order 4): the REAL config vocabulary — the keys
  /// [generateWithContext] reads from the shared make/context data. The
  /// old `{'properties': {}}` silently accepted anything (the #1122
  /// defect family); [validateStateConfig] now enforces this schema at
  /// the command and capability boundaries.
  @override
  JsonSchema get configSchema => stateConfigSchema;

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateState: true,
      methods:
          context.data['methods']?.cast<String>().toList() ??
          (context.data['no-entity'] == true
              ? []
              : ['get', 'update', 'toggle']),
      noEntity: context.data['no-entity'] == true,
      domain: context.data['domain'],
      usecases: context.data['usecases']?.cast<String>().toList() ?? [],
      paramsType: context.get<String>('params'),
      returnsType: context.get<String>('returns'),
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateState && !config.generateVpcs && !config.revert) {
      return [];
    }

    final builder = context != null
        ? StateBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: context.fileSystem,
          )
        : stateBuilder;

    final file = await builder.generate(config);
    return [file];
  }
}

/// Validates state config values against [schema] (default:
/// [stateConfigSchema]) and returns one human-readable violation per
/// problem. Empty list means the config is valid.
///
/// Runtime guard (spec 1126 order 4, the issue #1122 constraint): an
/// object schema whose `properties` is empty is REFUSED — an empty
/// schema would silently accept anything, which is exactly the C+
/// defect this upgrade removes.
///
/// Checks, per config entry:
/// * unknown property key (not declared by the schema) — the
///   "config schema rejects unknown keys" acceptance criterion,
/// * value type mismatch (`boolean` / `string` / `array`).
List<String> validateStateConfig(
  Map<String, dynamic> config, {
  JsonSchema? schema,
}) {
  final effective = schema ?? stateConfigSchema;
  final propsRaw = effective['properties'];
  final props = propsRaw is Map
      ? Map<String, dynamic>.from(propsRaw)
      : const <String, dynamic>{};
  if (props.isEmpty) {
    return [
      'state config schema is empty {} — refusing to validate: an empty '
          'schema would silently accept anything (spec 1126)',
    ];
  }

  final violations = <String>[];
  for (final entry in config.entries) {
    final key = entry.key;
    final value = entry.value;
    final propRaw = props[key];
    if (propRaw is! Map) {
      violations.add(
        "unknown state config property '$key' (allowed: "
        '${props.keys.join(', ')})',
      );
      continue;
    }
    final prop = Map<String, dynamic>.from(propRaw);
    switch (prop['type'] as String?) {
      case 'boolean':
        if (value is! bool) {
          violations.add(
            "state config '$key' must be a boolean, got "
            "'$value'",
          );
        }
      case 'string':
        if (value is! String) {
          violations.add("state config '$key' must be a string, got '$value'");
        }
      case 'array':
        if (value is! List) {
          violations.add("state config '$key' must be an array, got '$value'");
        } else {
          final items = prop['items'];
          final itemEnum = items is Map
              ? (Map<String, dynamic>.from(items)['enum'] as List?)
              : null;
          if (itemEnum != null) {
            for (final element in value) {
              if (!itemEnum.contains(element)) {
                violations.add(
                  "state config '$key' has unknown element '$element' "
                  '(allowed: ${itemEnum.map((v) => '$v').join(', ')})',
                );
              }
            }
          }
        }
      default:
        break;
    }
  }
  return violations;
}

/// The state plugin's config schema as a standalone constant so
/// [validateStateConfig] and the tests can reference the vocabulary
/// without instantiating the plugin.
const JsonSchema stateConfigSchema = {
  'type': 'object',
  'properties': {
    'methods': {
      'type': 'array',
      'items': {'type': 'string'},
      'default': ['get', 'update'],
      'description':
          'CRUD methods the state derives members from '
          '(get, create, update, delete, watch, getList, watchList).',
    },
    'no-entity': {
      'type': 'boolean',
      'default': false,
      'description':
          'Emit entity-free state (no entity field; custom '
          'mode).',
    },
    'domain': {
      'type': 'string',
      'description':
          'Domain folder the state file is emitted under '
          '(defaults to the entity snake name).',
    },
  },
};
