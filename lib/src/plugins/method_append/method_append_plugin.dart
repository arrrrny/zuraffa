import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import 'builders/method_append_builder.dart';
import 'capabilities/append_method_capability.dart';
import 'capabilities/method_capability.dart';

/// Manages appending methods to existing classes.
///
/// Provides capabilities to add new methods to repositories, services,
/// and data sources without overwriting existing files.
///
/// Example:
/// ```dart
/// final plugin = MethodAppendPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final result = await plugin.appendMethod(GeneratorConfig(name: 'Product'));
/// ```
class MethodAppendPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final GeneratorOptions options;
  late final MethodAppendBuilder methodAppendBuilder;

  MethodAppendPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  }) {
    methodAppendBuilder = MethodAppendBuilder(
      outputDir: outputDir,
      options: options,
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

    return generate(config);
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
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
      );
      return delegator.generate(config);
    }

    if (config.appendToExisting || config.revert) {
      final result = await appendMethod(config);
      return result.updatedFiles;
    }
    return [];
  }

  Future<MethodAppendResult> appendMethod(GeneratorConfig config) async {
    return methodAppendBuilder.appendMethod(config);
  }
}
