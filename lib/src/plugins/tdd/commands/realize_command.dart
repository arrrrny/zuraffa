/// `zfa tdd realize <entity|behavior> --adapter <real>` — the mock→real
/// swap with contract + differential gates and nuance receipts (spec 913,
/// parent #908 Mock-First Realization).
///
/// STUB (red phase): registered so the CLI surface exists, but every
/// behavior throws until its green phase lands.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

/// The contract-gate suite spawner (injectable for fast-tier tests — the
/// CorpusDifferentialCommand spawner pattern). Runs the mock-era suite
/// against one binding and reports exit code + combined output.
typedef RealizeSuiteRunner =
    Future<({int exitCode, String output})> Function(
      List<String> testPaths,
      String workingDirectory,
    );

class RealizeCommand extends Command<void> {
  RealizeCommand(this.plugin, {RealizeSuiteRunner? suiteRunner})
    : _suiteRunnerOverride = suiteRunner {
    argParser.addOption(
      'adapter',
      help: 'The real adapter class to bind (must already exist in lib/ — '
          'realize never generates real implementations). Required.',
    );
    argParser.addOption(
      'feature',
      help: 'Feature name (e.g. 047-tdd-make). Restricts state + registry '
          'resolution to specs/<feature>. When omitted, feature registries '
          'are scanned for the target.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root containing specs/, lib/, test/. Defaults to the '
          'current working directory.',
    );
  }

  final TddPlugin plugin;

  final RealizeSuiteRunner? _suiteRunnerOverride;

  @override
  String get name => 'realize';

  @override
  String get description =>
      'Swap the mock datasource for a real adapter behind the same '
      'generated interface, gated by the contract suite and the '
      'real-vs-mock differential (spec 913).';

  @override
  String get invocation =>
      'zfa tdd realize <entity|behavior> --adapter <real> [options]';

  @override
  Future<void> run() async => throw UnimplementedError();
}
