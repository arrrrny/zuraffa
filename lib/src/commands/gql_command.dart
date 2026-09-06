import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import '../plugins/gql/gql_plugin.dart';
import '../plugins/gql/capabilities/create_gql_capability.dart';

class GqlCommand extends PluginCommand {
  @override
  final GqlPlugin plugin;

  GqlCommand(this.plugin) : super(plugin) {
    argParser.addOption('returns', help: 'GraphQL return fields');
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'GraphQL operation type (query, mutation)',
      defaultsTo: 'query',
    );
  }

  @override
  String get name => 'gql';

  @override
  String get description => 'Generate internal GQL query/mutation strings';

  /// SPEC 917 / #876 sweep: run()'s programmatic positional path reads
  /// every parent-level flag listed below — they are LIVE, declared here so
  /// `zfa manifest --verify` certifies them instead of flagging them dead
  /// (spec #979).
  @override
  Set<String> get consumedParentFlags => const {'returns', 'type'};

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }
    final entityName = argResults!.rest.first;
    final type = argResults!['type'] as String?;
    final returns = argResults!['returns'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateGqlCapability)
            as CreateGqlCapability;

    // Issue #1138: route the standalone invocation through the
    // CapabilityInvocationWrapper so a successful run persists its
    // proof.v1 receipt (best-effort inside the wrapper).
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: plugin.id,
    );
    final result = await wrapper.execute({
      'name': entityName,
      'type': type,
      'returns': returns,
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
      // Bug #1139 (exit-code sweep, #856 pattern): a failed generation is a
      // failure — the process must never exit 0 after printing an error.
      print('❌ Failed to generate gql: ${result.message ?? "unknown error"}');
      exitCode = 1;
    }
  }
}
