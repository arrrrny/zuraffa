/// `zfa spec` — the spec-quality arena command family (spec
/// 0967-spec-mutation-arena, VISION §7, issue #967).
///
/// `spec` hosts the intent-layer adversaries as sibling subcommands.
/// `fuzz` is the referee round: deterministic spec mutations, re-run
/// the loop, killed/survived verdicts — mutation testing for intent,
/// the third leg after #811 (code mutation) and #805 (generator
/// differential).
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/tdd/commands/spec_fuzz_command.dart';
import '../plugins/tdd/services/mutation_auditor.dart';

class SpecCommand extends Command<void> {
  /// The injectable preflight/spawn seams (spec 1147): forwarded to the
  /// fuzz subcommand so fast-tier tests can drive the REAL family
  /// without subprocesses. Null = the real-process wiring, unchanged.
  SpecCommand({
    Future<PreflightResult> Function(List<String> testPaths)? runPreflight,
    Future<ProcessResult> Function(
      String executable,
      List<String> args,
      String workingDirectory,
      Duration timeout,
    )?
    spawnTest,
  }) {
    addSubcommand(
      SpecFuzzCommand(runPreflight: runPreflight, spawnTest: spawnTest),
    );
  }

  @override
  String get name => 'spec';

  @override
  String get description =>
      'Spec-quality arena: fuzz the spec contract with deterministic '
      'mutations and referee every round (killed = the tests pin the '
      'intent; survived = a proven spec weakness). See '
      'specs/0967-spec-mutation-arena for the contract.';

  @override
  String get invocation => 'zfa spec <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}
