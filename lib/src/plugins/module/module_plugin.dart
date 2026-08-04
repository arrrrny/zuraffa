import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../module/builders/module_orchestrator_builder.dart';
import '../module/capabilities/create_module_capability.dart';

/// Generates a [ZuraffaPlugin] orchestrator subclass for a feature package.
///
/// The generated plugin wires the feature's DI registrations and
/// route map into the ZuraffaEngine lifecycle.
class ModuleGeneratorPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final GeneratorOptions options;

  ModuleGeneratorPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateModuleCapability(this),
      ];

  @override
  String get id => 'module';

  @override
  String get name => 'Module Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generateWithContext(
    PluginContext context,
  ) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      domain: context.data['domain'],
    );
    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    final builder = ModuleOrchestratorBuilder(
      outputDir: config.outputDir,
      options: GeneratorOptions(
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
      ),
    );
    return builder.generate(config);
  }
}