/// `zfa tdd` — top-level TDD plugin command (feature 041).
library;

import 'package:args/command_runner.dart';

import '../plugins/tdd/commands/gen_command.dart';
import '../plugins/tdd/commands/init_command.dart';
import '../plugins/tdd/commands/make_command.dart';
import '../plugins/tdd/commands/plan_command.dart';
import '../plugins/tdd/commands/refactor_command.dart';
import '../plugins/tdd/commands/corpus_command.dart';
import '../plugins/tdd/commands/run_command.dart';
import '../plugins/tdd/commands/verify_command.dart';
import '../plugins/tdd/commands/verify_red_command.dart';
import '../plugins/tdd/commands/wire_command.dart';
import '../plugins/tdd/tdd_plugin.dart';

class TddCommand extends Command<void> {
  TddCommand(this.plugin) {
    addSubcommand(InitCommand(plugin));
    addSubcommand(PlanCommand(plugin));
    addSubcommand(CorpusCommand(plugin));
    addSubcommand(GenCommand(plugin));
    addSubcommand(VerifyRedCommand(plugin));
    addSubcommand(MakeCommand(plugin));
    addSubcommand(WireCommand(plugin));
    addSubcommand(RefactorCommand(plugin));
    addSubcommand(RunCommand(plugin));
    addSubcommand(VerifyCommand(plugin));
  }

  final TddPlugin plugin;

  @override
  String get name => 'tdd';

  @override
  String get description =>
      'Drive the full TDD red-green-refactor cycle (init, plan, gen, '
      'verify-red, make, wire, refactor, run, verify). See '
      'specs/041-tdd-setup-plugin/spec.md for the full contract.';

  @override
  String get invocation => 'zfa tdd <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}
