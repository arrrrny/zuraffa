import 'package:args/command_runner.dart';

import '../../core/generator_options.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/skin_builder.dart';
import 'capabilities/ui_vocabulary_export_capability.dart';
import 'commands/skin_command.dart';

/// Manages Skin UI widget generation (the zuraffa_ui certified lane).
class SkinPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final SkinBuilder skinBuilder;
  final FileSystem fileSystem;

  SkinPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    skinBuilder = SkinBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  Command createCommand() => SkinCommand(this);

  /// Spec 024 FR-006: the vocabulary export is a discoverable capability
  /// (MCP-accessible) on the skin plugin.
  @override
  List<ZuraffaCapability> get capabilities => [
    UiVocabularyExportCapability(this),
  ];

  @override
  String get id => 'skin';

  @override
  String get name => 'Skin UI Plugin';

  @override
  String get version => '1.0.0';

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'layout': {
        'type': 'string',
        // Issue #1149 (kill list — fix list): `grid` and `table` were
        // advertised but never implemented — the builder's switch falls
        // through to the list template, emitting a mislabeled widget.
        // Advertise exactly what exists; the command refuses the rest.
        'enum': ['list', 'form'],
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
        ? SkinBuilder(
            outputDir: outputDir,
            options: options,
            fileSystem: fs,
            discovery: context.discovery,
          )
        : skinBuilder;

    return builder.generate(config, context?.data ?? {});
  }
}
