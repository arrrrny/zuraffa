import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import 'base_plugin_command.dart';
import 'graphql_diff_command.dart';
import 'graphql_introspect_command.dart';
import 'graphql_pull_command.dart';
import '../plugins/graphql/graphql_plugin.dart';
import '../plugins/graphql/capabilities/create_graphql_capability.dart';

class GraphqlCommand extends PluginCommand {
  @override
  final GraphqlPlugin plugin;

  GraphqlCommand(this.plugin) : super(plugin) {
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'GraphQL operation type (query, mutation)',
      defaultsTo: 'query',
    );
    argParser.addOption('returns', help: 'Return type');
    argParser.addOption('input-type', help: 'Input type name');
    argParser.addOption('input-name', help: 'Input variable name');
    argParser.addOption('op-name', help: 'Operation name');

    // Register subcommands: introspect (v5), pull + diff (spec 037).
    addSubcommand(IntrospectCommand());
    addSubcommand(PullCommand());
    addSubcommand(DiffCommand());
  }

  @override
  String get name => 'graphql';

  @override
  String get description => 'Generate GraphQL files';

  /// SPEC 917 / #876 sweep: run()'s programmatic positional path reads
  /// every parent-level flag listed below — they are LIVE, declared here so
  /// `zfa manifest --verify` certifies them instead of flagging them dead
  /// (spec #979).
  @override
  Set<String> get consumedParentFlags => const {
    'input-name',
    'input-type',
    'op-name',
    'returns',
    'type',
  };

  @override
  Future<void> run() async {
    if (argResults?.rest.isEmpty ?? true) {
      reportSubcommandUsage();
      return;
    }
    final entityName = argResults!.rest.first;
    final type = argResults!['type'] as String?;
    final returns = argResults!['returns'] as String?;
    final inputType = argResults!['input-type'] as String?;
    final inputName = argResults!['input-name'] as String?;
    final opName = argResults!['op-name'] as String?;

    final capability =
        plugin.capabilities.firstWhere((c) => c is CreateGraphqlCapability)
            as CreateGraphqlCapability;

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
      'inputType': inputType,
      'inputName': inputName,
      'opName': opName,
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
      print(
        '❌ Failed to generate graphql: '
        '${result.message ?? "unknown error"}',
      );
      exitCode = 1;
    }
  }
}
