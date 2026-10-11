import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'dart:convert';
import 'dart:io';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../models/generated_file.dart';
import '../cli/exit_protocol.dart';
import '../cli/zfa_executable.dart';
import '../plugins/plugin_gate/plugin_gate.dart';
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
    // Spec 1653 (issue #1661): `generate` delegates to the companion
    // (package:zuraffa_graphql) through the ZfaExecutable no-JIT seam.
    addSubcommand(_GenerateDelegateCommand());
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
    // Spec 1653 (issue #1661): the graphql capability is opt-in — the
    // heavy codegen/client surface lives in package:zuraffa_graphql.
    // Refuse BEFORE any generation when the gate is not satisfied.
    final gateRefusal = PluginGate.refusalFor('graphql');
    if (gateRefusal != null) {
      print('❌ $gateRefusal');
      exitCode = ExitProtocol.usage;
      return;
    }
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
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

/// Spec 1653 (issue #1661): the `zfa graphql generate` delegate. The
/// schema-driven full-stack codegen lives in package:zuraffa_graphql —
/// this thin subcommand enforces the capability gate and then spawns the
/// companion's `bin/zuraffa_graphql.dart generate <args>` through the
/// `ZfaExecutable` no-JIT seam, forwarding stdout/stderr and the exit
/// code verbatim.
class _GenerateDelegateCommand extends Command<void> {
  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate full-stack Dart code from a GraphQL schema (via '
      'package:zuraffa_graphql)';

  @override
  ArgParser get argParser => ArgParser.allowAnything();

  @override
  Future<void> run() async {
    final gateRefusal = PluginGate.refusalFor('graphql');
    if (gateRefusal != null) {
      print('❌ $gateRefusal');
      exitCode = ExitProtocol.usage;
      return;
    }
    final entry = PluginGate.companionEntry('graphql');
    if (entry == null) {
      print(
        '\u274c zuraffa_graphql is resolvable but its bin entry is missing \u2014 '
        're-add package:zuraffa_graphql and run dart pub get.',
      );
      exitCode = ExitProtocol.usage;
      return;
    }
    // Issue #1690 §2: the companion compile must resolve through THIS
    // project's package config. Without it, a hosted companion's compile
    // falls back to the candidate's own root — a pub-cache package dir
    // with a pubspec.yaml but no package config — and runs Dart's implicit
    // `pub get` inside the shared pub cache. The gate proved the config
    // exists (isResolvable reads it); a null here is a mid-run race, and
    // refusing beats silently resurrecting the pub-cache-mutating seam.
    final packagesFile = PluginGate.packageConfigPath();
    if (packagesFile == null) {
      print(
        '\u274c .dart_tool/package_config.json is missing \u2014 the graphql '
        'companion needs the project\u2019s package resolution to compile.\n'
        "   --> fix: run 'dart pub get' in this project",
      );
      exitCode = ExitProtocol.usage;
      return;
    }
    final exe = await ZfaExecutable.ensureCompiled(
      entry,
      packagesFile: packagesFile,
    );
    final argv = ZfaExecutable.commandFor(exe, [
      'generate',
      ...argResults!.arguments,
    ]);
    final result = await Process.run(
      argv.first,
      argv.sublist(1),
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    // Forward through `print` (not `stdout.write`) so embedded CliRunner
    // runs capture the child's transcript the same way a terminal does.
    result.stdout
        .toString()
        .split('\n')
        .where((l) => l.isNotEmpty)
        .forEach(print);
    final errText = result.stderr.toString();
    if (errText.isNotEmpty) stderr.write(errText);
    exitCode = result.exitCode;
  }
}
