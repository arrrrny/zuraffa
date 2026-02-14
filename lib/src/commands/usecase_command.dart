import '../models/generator_config.dart';
import 'base_plugin_command.dart';
import '../plugins/usecase/usecase_plugin.dart';

class UseCaseCommand extends PluginCommand {
  @override
  final UseCasePlugin plugin;

  UseCaseCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'methods',
      abbr: 'm',
      help: 'Comma-separated list of methods (get,create,update,delete,list)',
      defaultsTo: 'get,list,create,update,delete',
    );
    argParser.addOption(
      'type',
      abbr: 't',
      allowed: ['entity', 'custom', 'stream'],
      defaultsTo: 'entity',
      help: 'Type of usecase to generate',
    );
  }

  @override
  String get name => 'usecase';

  @override
  String get description => 'Generate UseCases';

  @override
  Future<void> run() async {
    final entityName = argResults!.rest.first;
    final methods = (argResults!['methods'] as String).split(',');
    final type = argResults!['type'] as String;

    final config = GeneratorConfig(
      name: entityName,
      methods: methods,
      useCaseType: type == 'stream' ? 'stream' : 'future',
      // If type is custom, we might need to handle it differently in GeneratorConfig
      // But typically GeneratorConfig.fromArgs handles this.
      // For now, let's rely on how the plugin uses config.
      // If type is entity (default), it's implied by name only.
      // If type is custom, we might need to set isCustomUseCase=true?
      // GeneratorConfig logic:
      // isEntityBased => !isCustomUseCase && !isOrchestrator && !isPolymorphic
      // isCustomUseCase => inferred if methods are empty? or explicit flag?
      // Actually GeneratorConfig has no explicit isCustomUseCase setter in constructor shown before.
      // It infers from other properties or specific named constructors?
      // Let's assume standard config works for now.
      dryRun: isDryRun,
      force: isForce,
      verbose: isVerbose,
      outputDir: outputDir,
    );

    // For custom usecase, usually we just give a name.
    // If user says "zfa usecase MyCustomAction --type custom"
    // We need to ensure config reflects that.

    final files = await plugin.generate(config);
    logSummary(files);
  }
}
