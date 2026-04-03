import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/method_append_builder.dart';
import 'capabilities/append_method_capability.dart';
import 'capabilities/method_capability.dart';

/// Manages appending methods to existing classes.
class MethodAppendPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final MethodAppendBuilder methodAppendBuilder;
  final FileSystem fileSystem;

  MethodAppendPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create() {
    methodAppendBuilder = MethodAppendBuilder(
      outputDir: outputDir,
      options: options,
      fileSystem: this.fileSystem,
    );
  }

  @override
  List<ZuraffaCapability> get capabilities => [
    AppendMethodCapability(this),
    MethodCapability(
      this,
      methodAppendBuilder: methodAppendBuilder,
      targetType: 'any',
    ),
  ];

  @override
  String get id => 'method_append';

  @override
  String get name => 'Method Append Plugin';

  @override
  String get version => '1.0.0';

  @override
  String? get configKey => 'appendByDefault';

  @override
  List<String> get runAfter => [
    'usecase',
    'repository',
    'service',
    'datasource',
    'provider',
  ];

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'append': {
        'type': 'boolean',
        'default': false,
        'description': 'Append methods to existing files',
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
      appendToExisting:
          context.get<bool>('append') ?? context.data['append'] == true,
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
    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = MethodAppendPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    if (config.appendToExisting || config.revert) {
      final fs = context?.fileSystem ?? fileSystem;
      final builder = context != null
          ? MethodAppendBuilder(
              outputDir: outputDir,
              options: options,
              fileSystem: fs,
              discovery: context.discovery,
            )
          : methodAppendBuilder;

      final result = await builder.appendMethod(config);
      return result.updatedFiles;
    }
    return [];
  }

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    return methodAppendBuilder.appendMethod(config);
  }
}
