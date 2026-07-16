import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/strategy/strategy_plugin.dart';
import '../plugins/strategy/capabilities/create_strategy_capability.dart';

/// CLI command: `zfa strategy create <Name> --strategies=scraper,ai --params=Input --returns=Output`
///
/// Follows the canonical [PluginCommand] contract exactly:
///   - Capabilities are registered as subcommands automatically by [PluginCommand].
///   - `zfa strategy create UrlListing --strategies=scraper,ai` routes through
///     [CapabilityCommand] for the `create` subcommand.
///   - `run()` is a direct-invocation fallback (no subcommand prefix) kept for
///     parity with [SyncCommand] and [RepositoryCommand].
class StrategyCommand extends PluginCommand {
  @override
  final StrategyPlugin plugin;

  StrategyCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'strategies',
      help: 'Comma-separated strategy variant names (e.g. scraper,ai)',
      mandatory: true,
    );
    argParser.addOption(
      'params',
      help: 'Input type for FetchStrategy<Input, Output> (e.g. UrlSpark)',
    );
    argParser.addOption(
      'returns',
      help: 'Output type for FetchStrategy<Input, Output> (e.g. Listing)',
    );
    argParser.addOption(
      'domain',
      help: 'Provider domain folder (defaults to name in snake_case)',
    );
  }

  @override
  String get name => 'strategy';

  @override
  String get description =>
      'Generate FetchStrategy abstract base, concrete variants, and StrategySelector';

  @override
  Future<void> run() async {
    // Delegate to subcommand (e.g. `zfa strategy create`) if one was given.
    final command = argResults?.command;
    if (command != null) return super.run();

    if (argResults?.rest.isEmpty ?? true) {
      print(
        '❌ Usage: zfa strategy create <Name> --strategies=scraper,ai [options]',
      );
      printUsage();
      return;
    }

    final entityName = argResults!.rest.first;
    final strategies = argResults!['strategies'] as String? ?? '';
    final params = argResults!['params'] as String?;
    final returns = argResults!['returns'] as String?;
    final domain = argResults!['domain'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateStrategyCapability)
            as CreateStrategyCapability;

    final result = await capability.execute({
      'name': entityName,
      'strategies': strategies,
      'params': params,
      'returns': returns,
      'domain': domain,
      'dryRun': isDryRun,
      'force': isForce,
      'verbose': isVerbose,
      'outputDir': outputDir,
    });

    if (result.success) {
      final files =
          result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
      logSummary(files);
    } else {
      print('❌ Failed to generate strategies');
    }
  }
}
