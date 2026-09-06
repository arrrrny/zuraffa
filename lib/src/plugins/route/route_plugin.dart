import 'package:args/command_runner.dart';

import '../../commands/route_command.dart';
import '../../core/context/file_system.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/manifest_writer.dart';
import 'builders/route_builder.dart';
import 'capabilities/create_route_capability.dart';
import 'capabilities/custom_route_capability.dart';
import 'capabilities/deep_link_route_capability.dart';
import 'capabilities/shell_route_capability.dart';

/// The route plugin's config schema (issue #1122 — the A+ upgrade).
///
/// The schema used to be the empty `{'properties': {}}`, which silently
/// accepted anything. It now declares the real route config vocabulary:
///
/// * `shell` — the shell binding a route targets. The enum lists the
///   shell kinds [ShellRouteCapability] actually emits (the
///   `--bottom-nav` / `--rail` / `--adaptive` grammar of
///   `zfa route shell`), plus `none` for standalone entity routes.
///   Unknown shell names are rejected at runtime by
///   [validateRouteConfig] with the usage exit code (the issue's
///   "exit 64", which the ratified SPEC 917 protocol canonicalizes onto
///   `ExitProtocol.usage`).
/// * `deep-link` — whether the route participates in deep-link
///   registration (the `--scheme`/`--host` grammar).
/// * `platform-matrix` — the platform slots a route targets, per spec
///   #1000 K-TRACK. The vocabulary is the Skin Contract's platform row
///   columns (`mobile` / `ios` / `android` / `macos`): the same matrix
///   `zfa tdd` skin-contract schema emits (feature 078).
/// * `guard` — the route guard binding (the GoRoute `redirect:` seam).
///   Free-form: guards are user code, so type-checked only.
/// * `state-machine` — the state binding the route's view references,
///   per spec #1004 Skin Contract (the stateRows `observer` / `listener`
///   kinds), plus `none`.
const JsonSchema routeConfigSchema = {
  'type': 'object',
  'properties': {
    'shell': {
      'type': 'string',
      'enum': ['none', 'bottom-nav', 'rail', 'adaptive'],
      'default': 'none',
      'description':
          'Shell binding for the route: which shell kind targets it '
          '(none, bottom-nav, rail, adaptive).',
    },
    'deep-link': {
      'type': 'boolean',
      'default': false,
      'description':
          'Whether the route participates in deep-link registration '
          '(--scheme/--host writes the Android intent-filter + iOS '
          'CFBundleURLSchemes entry).',
    },
    'platform-matrix': {
      'type': 'array',
      'items': {
        'type': 'string',
        'enum': ['mobile', 'ios', 'android', 'macos'],
      },
      'default': ['mobile', 'ios', 'android', 'macos'],
      'description':
          'Platform slots the route targets (spec #1000 K-TRACK): the '
          'Skin Contract platform row columns.',
    },
    'guard': {
      'type': 'string',
      'default': 'none',
      'description':
          'Route guard binding: the redirect guard name guarding the '
          'route, or none.',
    },
    'state-machine': {
      'type': 'string',
      'enum': ['none', 'observer', 'listener'],
      'default': 'none',
      'description':
          'State binding the route view references (spec #1004 Skin '
          'Contract stateRows kinds: observer, listener), or none.',
    },
  },
};

/// Validates route config values against [schema] (default:
/// [routeConfigSchema]) and returns one human-readable violation per
/// problem. Empty list means the config is valid.
///
/// Runtime guard (issue #1122 constraint): an object schema whose
/// `properties` is empty is REFUSED — an empty schema would silently
/// accept anything, which is exactly the B+ defect this upgrade removes.
///
/// Checks, per config entry:
/// * unknown property key (not declared by the schema),
/// * value type mismatch (`boolean` / `string` / `array`),
/// * enum mismatch — for scalars against `enum`, for array elements
///   against `items.enum` (this is what rejects unknown route shell
///   names like `--shell bogus`).
List<String> validateRouteConfig(
  Map<String, dynamic> config, {
  JsonSchema? schema,
}) {
  final effective = schema ?? routeConfigSchema;
  final propsRaw = effective['properties'];
  final props = propsRaw is Map
      ? Map<String, dynamic>.from(propsRaw)
      : const <String, dynamic>{};
  if (props.isEmpty) {
    return [
      'route config schema is empty {} — refusing to validate: an empty '
          'schema would silently accept anything (issue #1122)',
    ];
  }

  String enumNames(List allowed) => allowed.map((v) => '$v').join(', ');

  final violations = <String>[];
  for (final entry in config.entries) {
    final key = entry.key;
    final value = entry.value;
    final propRaw = props[key];
    if (propRaw is! Map) {
      violations.add(
        "unknown route config property '$key' (allowed: "
        '${props.keys.join(', ')})',
      );
      continue;
    }
    final prop = Map<String, dynamic>.from(propRaw);
    final type = prop['type'] as String?;
    switch (type) {
      case 'boolean':
        if (value is! bool) {
          violations.add("route config '$key' must be a boolean, got '$value'");
        }
      case 'string':
        if (value is! String) {
          violations.add("route config '$key' must be a string, got '$value'");
        }
      case 'array':
        if (value is! List) {
          violations.add("route config '$key' must be an array, got '$value'");
        } else {
          final items = prop['items'];
          final itemEnum = items is Map
              ? (Map<String, dynamic>.from(items)['enum'] as List?)
              : null;
          if (itemEnum != null) {
            for (final element in value) {
              if (!itemEnum.contains(element)) {
                violations.add(
                  "route config '$key' has unknown element '$element' "
                  '(allowed: ${enumNames(itemEnum)})',
                );
              }
            }
          }
        }
    }
    final allowed = prop['enum'];
    if (allowed is List && value is! List && !allowed.contains(value)) {
      violations.add(
        "unknown route $key name '$value' (allowed: ${enumNames(allowed)})",
      );
    }
  }
  return violations;
}

/// Manages navigation route generation for Flutter applications.
///
/// Builds application-level route constants and entity-specific route builders,
/// ensuring type-safe navigation and route argument handling.
///
/// Example:
/// ```dart
/// final plugin = RoutePlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class RoutePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final String projectRoot;
  final GeneratorOptions options;
  final FileSystem fileSystem;
  late final RouteBuilder routeBuilder;
  late final ManifestWriter manifestWriter;

  RoutePlugin({
    required this.outputDir,
    this.projectRoot = '.',
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? const DefaultFileSystem() {
    routeBuilder = RouteBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
    manifestWriter = ManifestWriter(fileSystem: this.fileSystem);
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateRouteCapability(this),
    CustomRouteCapability(this),
    DeepLinkRouteCapability(this),
    ShellRouteCapability(this),
  ];

  @override
  Command createCommand() => RouteCommand(this);

  @override
  String get id => 'route';

  @override
  String get name => 'Route Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'routeByDefault';

  @override
  JsonSchema get configSchema => routeConfigSchema;

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateRoute: true,
      generateVpcs: context.get<bool>('vpc') ?? context.data['vpcs'] == true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      usecases: (context.data['usecases'] as List?)?.cast<String>() ?? [],
      domain: context.data['domain'],
      noEntity: context.data['no-entity'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateRoute && !config.revert) {
      return [];
    }
    // Re-create builder with config flags if needed, or update builder to use config
    final builder = RouteBuilder(
      outputDir: config.outputDir,
      options: GeneratorOptions(
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        revert: config.revert,
      ),
      fileSystem: context?.fileSystem ?? fileSystem,
      discovery: context?.discovery,
    );
    return builder.generate(config);
  }
}
