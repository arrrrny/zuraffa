import 'dart:io';

import '../models/generated_file.dart';
import '../plugins/api/api_plugin.dart';
import '../plugins/api/capabilities/create_api_bridge_capability.dart';
import 'base_plugin_command.dart';

/// CLI command for `zfa api <EntityName>`.
///
/// Generates a VM Service extension bridge file for the given entity.
/// The generated file lives at `lib/src/api/bridges/{entity_snake}_api_bridge.dart`
/// and contains a `register{EntityName}ApiBridge()` top-level function that
/// registers every UseCase of that entity as a `dart:developer` extension.
class ApiCommand extends PluginCommand {
  @override
  final ApiPlugin plugin;

  ApiCommand(this.plugin) : super(plugin, registerSubcommands: false) {
    argParser.addOption(
      'name',
      help: 'Entity name (alternative to the positional argument)',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Override the domain name segment in extension methods',
    );
  }

  @override
  String get name => 'api';

  @override
  String get description => 'Generate API bridge for a Zuraffa entity';

  @override
  String get invocation => 'zfa api <EntityName> [options]';

  @override
  Future<void> run() async {
    // Dispatch to subcommands (e.g. capabilities registered by PluginCommand).
    final command = argResults?.command;
    if (command != null) {
      return super.run();
    }

    // The manifest advertises this capability as `api create-api-bridge`;
    // treat that name as an optional alias so manifest-driven invocations
    // and the plain positional form both work.
    final positional = argResults!.rest
        .where((r) => r != 'create-api-bridge')
        .toList();

    if (positional.isEmpty && argResults?['name'] == null) {
      print('❌ Usage: zfa api <EntityName> [options]');
      print('   Example: zfa api Product');
      exit(64);
    }

    final entityName = positional.isNotEmpty
        ? positional.first
        : argResults!['name'] as String;
    final domain = argResults!['domain'] as String?;

    final capability = plugin.capabilities
        .whereType<CreateApiBridgeCapability>()
        .firstOrNull;
    if (capability == null) {
      print('❌ Internal error: CreateApiBridgeCapability not found');
      return;
    }

    final result = await capability.execute({
      'name': entityName,
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
      print('❌ Failed to generate API bridge: ${result.message}');
    }
  }
}
