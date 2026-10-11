import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/project/project_root.dart';
import '../models/generated_file.dart';
import '../cli/exit_protocol.dart';
import '../plugins/test/capabilities/create_test_capability.dart';
import '../plugins/test/test_explain.dart';
import '../plugins/test/test_plugin.dart';

/// The bespoke `zfa test create` subcommand (spec 1129).
///
/// Why hand-rolled: the generic [CapabilityCommand] registers `--json` as
/// the machine-INPUT option (`--json '<args>'`), so `--explain --json`
/// could not parse on the create grammar. Following the sanctioned route
/// precedent (issue #971 orders 2-5: `RouteCommand` registers
/// `RouteCreateCommand` manually; `manualSubcommandNames` skips the
/// generic registration), `--json` here is the machine-OUTPUT flag with
/// the spec 980 FR-002 semantics — the single-line self-certification
/// envelope `{entity, tests, compile, errors[], schema:1}`, keys and
/// meaning unchanged — and `--explain` (spec 1129) prints the
/// human-readable block after the regular output. Both flags may be
/// passed together: envelope first, then prose.
///
/// Generation is NOT duplicated: the command delegates to
/// `CreateTestCapability.execute()` through
/// [CapabilityInvocationWrapper], so the self-certification gate, the
/// exit-code contract (#767) and the proof receipts (#996) are the same
/// machinery the capability grammar always ran.
class TestCreateCommand extends Command<void> {
  final TestPlugin plugin;

  /// Project root the receipt store lives under (issue #996). Defaults
  /// to the resolved project root; tests inject a temp fixture.
  final String? projectRoot;

  TestCreateCommand(this.plugin, {this.projectRoot}) {
    argParser.addOption(
      'name',
      help: 'Name of the test target (alternative to the positional argument)',
    );
    argParser.addMultiOption(
      'methods',
      help:
          'Comma-separated list of methods '
          '(get,create,update,delete,list,watch,getList,watchList)',
    );
    argParser.addOption(
      'domain',
      help: 'Domain folder for custom usecases',
      defaultsTo: 'general',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Print the test self-certification envelope '
          '{entity, tests, compile, errors[], schema:1} as JSON '
          '(the spec 980 FR-002 semantics; keys unchanged)',
    );
    argParser.addFlag('explain', negatable: false, help: kTestExplainFlagHelp);
  }

  @override
  String get name => 'create';

  @override
  String get description => 'Create a Test';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    final positional = rest.isNotEmpty ? rest.first : null;
    final name = (argResults!['name'] as String?) ?? positional;
    if (name == null || name.isEmpty) {
      print('❌ Error: Missing required arguments: name');
      print('   --> fix: zfa test create <Entity> (or --name <Entity>)');
      exitCode = ExitProtocol.usage;
      return;
    }

    final args = <String, dynamic>{
      'name': name,
      'domain': argResults!['domain'] as String? ?? 'general',
      'force': argResults!['force'] == true,
      'verbose': argResults!['verbose'] == true,
      'explain': argResults!['explain'] == true,
    };
    final methods = argResults!['methods'] as List<String>;
    if (methods.isNotEmpty) {
      args['methods'] = methods;
    }
    if (argResults!['dry-run'] == true) {
      args['dryRun'] = true;
    }
    if (argResults!['revert'] == true) {
      args['revert'] = true;
    }

    // The SAME execution path as the generic grammar: gate, receipts and
    // ExecutionResult contract all come from the capability itself.
    final wrapper = CapabilityInvocationWrapper(
      capability: CreateTestCapability(plugin),
      pluginId: plugin.id,
      projectRoot: projectRoot ?? ProjectRoot.find(),
    );
    final result = await wrapper.execute(args);

    final jsonMode = argResults!['json'] == true;
    final explain = result.data?['explain'] as String?;
    final certification =
        result.data?['certification'] as Map<String, dynamic>?;
    final files =
        result.data?['generatedFiles'] as List<GeneratedFile>? ??
        const <GeneratedFile>[];

    // The machine envelope comes first when requested (FR-003): JSON,
    // then the regular output, then the explain prose.
    if (jsonMode && certification != null) {
      print(jsonEncode(certification));
    }

    if (!result.success) {
      // The self-certification gate is unchanged (FR-005): non-compiling
      // output fails the command. Honesty on every exit path: the
      // explain block still prints when requested.
      print('❌ Failed: ${result.message}');
      if (explain != null && explain.isNotEmpty) {
        print(explain);
      }
      exitCode = 1;
      return;
    }

    // Issue #769 zero-files guard, CapabilityCommand parity: a run that
    // produced nothing is not dressed up as success.
    if (files.isEmpty) {
      print(
        '⚠️ No files were generated (nothing changed). If the '
        'generator printed a skip note above, re-run inside a '
        'project that satisfies its guard; otherwise re-run with '
        '--verbose to inspect the resolved arguments.',
      );
      if (explain != null && explain.isNotEmpty) {
        print(explain);
      }
      exitCode = 1;
      return;
    }

    // The regular output (CapabilityCommand printout shape): the plugin
    // already printed the machine verdict line.
    final created = files.where((f) => f.action == 'created').toList();
    final overwritten = files.where((f) => f.action == 'overwritten').toList();
    final updated = files.where((f) => f.action == 'updated').toList();
    final skipped = files.where((f) => f.action == 'skipped').toList();
    final deleted = files.where((f) => f.action == 'deleted').toList();

    if (created.isNotEmpty ||
        overwritten.isNotEmpty ||
        updated.isNotEmpty ||
        deleted.isNotEmpty) {
      print('✅ Success! Created/Modified:');
      for (final file in created) {
        print('  ✨ ${file.path}');
      }
      for (final file in overwritten) {
        print('  📝 ${file.path}');
      }
      for (final file in updated) {
        print('  📝 ${file.path}');
      }
      for (final file in deleted) {
        print('  🗑 ${file.path}');
      }
    }

    if (skipped.isNotEmpty) {
      print('\n⏭ Skipped (use --force to overwrite):');
      for (final file in skipped) {
        print('  ${file.path}');
      }
    }

    // Spec 1129: the explain block, alongside the regular output (order
    // 2) — printed verbatim after the file list, exit stays 0.
    if (explain != null && explain.isNotEmpty) {
      print(explain);
    }
  }
}
