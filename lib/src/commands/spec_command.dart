/// `zfa spec` — the spec-quality arena command family (spec
/// 0967-spec-mutation-arena, VISION §7, issue #967).
///
/// `spec` hosts the intent-layer adversaries as sibling subcommands.
/// `fuzz` is the referee round: deterministic spec mutations, re-run
/// the loop, killed/survived verdicts — mutation testing for intent,
/// the third leg after #811 (code mutation) and #805 (generator
/// differential).
library;

import 'package:args/command_runner.dart';

import '../plugins/tdd/commands/spec_fuzz_command.dart';

class SpecCommand extends Command<void> {
  SpecCommand() {
    addSubcommand(SpecFuzzCommand());
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
