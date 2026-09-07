import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';

import '../models/generator_config.dart';
import '../models/generator_result.dart';
import 'base_plugin_command.dart';
import 'test_create_command.dart';
import '../plugins/test/test_plugin.dart';

/// CLI command that generates tests for existing use cases.
///
/// Supports analyzing existing usecase files to infer repositories, services,
/// and orchestrator dependencies when present.
class TestCommand extends PluginCommand {
  @override
  final TestPlugin plugin;

  /// Creates a command bound to the provided [plugin].
  ///
  /// [projectRoot] scopes the receipt store (issue #996) for tests and
  /// embedded runners; the CLI resolves it from the working directory.
  TestCommand(this.plugin, {String? projectRoot}) : super(plugin) {
    // SPEC 917 / #876 classification: these parent-level flags ARE live —
    // [execute] (the programmatic/MCP path) parses the shared parent
    // grammar below. run() is dispatch-only, so the gate certifies them
    // through [consumedParentFlags] (spec #979) instead of flagging them
    // dead: they are parsed, advertised, and read.
    argParser.addOption(
      'methods',
      abbr: 'm',
      help:
          'Comma-separated list of methods (get,create,update,delete,list,watch,getList,watchList)',
      defaultsTo: '',
    );
    argParser.addOption(
      'domain',
      abbr: 'd',
      help: 'Domain folder for custom usecases',
      defaultsTo: 'general',
    );
    // Spec 980 / FR-002: machine-readable verdict envelope. When set, the
    // command prints the single-line JSON envelope
    // `{entity, tests, compile, errors[], schema:1}` for the self-certified
    // compile verdict (real runs only — a dry run writes no files, so
    // there is nothing to certify and no envelope is printed).
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Print the test self-certification envelope '
          '{entity, tests, compile, errors[], schema:1} as JSON',
    );

    // Spec 1129: `create` is a MANUAL subcommand (TestCreateCommand) so
    // `--json` can be the machine verdict OUTPUT flag on the live create
    // grammar (the route precedent, issue #971 orders 2-5) and
    // `--explain` (spec 1129) can ride the same surface. The generic
    // CapabilityCommand registration is skipped via
    // [manualSubcommandNames]; the capability itself stays the single
    // execution path behind the bespoke command.
    addSubcommand(TestCreateCommand(plugin, projectRoot: projectRoot));
  }

  @override
  Set<String> get manualSubcommandNames => const {'create'};

  /// SPEC 917 / #876: [execute] reads --methods/--domain/--json off the
  /// parent grammar (see the constructor); declared so
  /// `zfa manifest --verify` certifies them as live.
  @override
  Set<String> get consumedParentFlags => const {'methods', 'domain', 'json'};

  @override
  /// Command identifier used by the CLI registry.
  String get name => 'test';

  @override
  /// Short description shown in help output.
  String get description => 'Generate Tests';

  /// Executes the command for the provided argument list.
  ///
  /// Returns a [GeneratorResult] instead of exiting when
  /// [exitOnCompletion] is false.
  Future<GeneratorResult> execute(
    List<String> args, {
    bool exitOnCompletion = true,
  }) async {
    if (args.isEmpty) {
      print('❌ Usage: zfa test <Name> [options]');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing arguments'],
        nextSteps: [],
      );
    }

    if (args[0] == '--help' || args[0] == '-h') {
      if (exitOnCompletion) exit(0);
      return GeneratorResult(
        name: 'help',
        success: true,
        files: [],
        errors: [],
        nextSteps: [],
      );
    }

    final entityName = args[0];
    if (entityName.startsWith('--')) {
      print('❌ Missing name');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing name'],
        nextSteps: [],
      );
    }

    final ArgResults results;
    try {
      results = argParser.parse(args.skip(1).toList());
    } on FormatException catch (e) {
      print('❌ ${e.message}');
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: [e.message],
        nextSteps: [],
      );
    }

    final methodsValue = results['methods'] as String;
    final methods = methodsValue.trim().isEmpty
        ? <String>[]
        : methodsValue.split(',').where((m) => m.trim().isNotEmpty).toList();
    final domain = results['domain'] as String? ?? 'general';
    final output = results['output'] as String? ?? 'lib/src';
    final dryRun = results['dry-run'] == true;
    final force = results['force'] == true;
    final verbose = results['verbose'] == true;
    final jsonMode = results['json'] == true;

    final analyzed = await plugin.buildConfigFromUseCase(
      entityName,
      output,
      domain,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );
    final config =
        analyzed ??
        GeneratorConfig(
          name: entityName,
          methods: methods,
          domain: domain,
          generateTest: true,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
          outputDir: output,
        );

    try {
      final files = await plugin.generate(config);

      // Spec 980 / FR-001: the plugin self-certified the generated tests
      // (scoped dart analyze + machine verdict line, already printed by
      // the plugin). Non-compiling output fails the command — never a
      // silent success. A dry run (or nothing written) certifies nothing
      // and keeps the previous success semantics.
      final certification = plugin.lastCertification;
      final compilePassed = certification?.compile ?? true;

      if (jsonMode && certification != null) {
        print(jsonEncode(certification.toJson()));
      }

      if (!compilePassed) {
        final verdict = certification!.verdictLine;
        print('❌ Generated tests do not compile: $verdict');
        if (exitOnCompletion) exit(1);
        return GeneratorResult(
          name: entityName,
          success: false,
          files: files,
          errors: [verdict],
          nextSteps: [
            'Fix the compile errors above (the first error is named in the verdict line)',
          ],
        );
      }

      return GeneratorResult(
        name: entityName,
        success: true,
        files: files,
        errors: [],
        nextSteps: [],
      );
    } catch (e) {
      if (exitOnCompletion) exit(1);
      return GeneratorResult(
        name: entityName,
        success: false,
        files: [],
        errors: [e.toString()],
        nextSteps: [],
      );
    }
  }

  @override
  /// Runs the command using parsed CLI args.
  Future<void> run() async {
    // Bug #856: the positional grammar this command's usage strings
    // advertised (`zfa test <EntityName>`) is unreachable through the
    // CLI — package:args rejects a bare entity name as a subcommand attempt
    // before run() ever executes. The subcommand grammar is the only live
    // contract (`zfa manifest`): `zfa test create --name <Entity>`.
    reportSubcommandUsage();
  }
}
