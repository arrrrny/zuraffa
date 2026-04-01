import 'package:args/command_runner.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/shadcn_builder.dart';
import 'commands/shadcn_command.dart';

/// Manages Shadcn UI widget generation.
class ShadcnPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final ShadcnBuilder shadcnBuilder;
  final FileSystem fileSystem;

  ShadcnPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(root: outputDir) {
    shadcnBuilder = ShadcnBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  Command createCommand() => ShadcnCommand(this);

  @override
  String get id => 'shadcn';

  @override
  String get name => 'Shadcn UI Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'layout': {
        'type': 'string',
        'enum': ['list', 'grid', 'table', 'form'],
        'default': 'list',
        'description': 'UI layout type',
      },
      'filter': {
        'type': 'boolean',
        'default': false,
        'description': 'Enable filtering',
      },
      'sort': {
        'type': 'boolean',
        'default': false,
        'description': 'Enable sorting',
      },
      'ignore-fields': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Fields to exclude from UI',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
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
    final fs = context?.fileSystem ?? fileSystem;
    final builder = context != null
        ? ShadcnBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
            discovery: context.discovery,
          )
        : shadcnBuilder;

    return builder.generate(config, context?.data ?? {});
  }
}
