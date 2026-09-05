/// `zfa tdd` — top-level TDD plugin command (feature 041).
library;

import 'package:args/command_runner.dart';

import '../plugins/tdd/commands/compose_command.dart';
import '../plugins/tdd/commands/corpus_command.dart';
import '../plugins/tdd/commands/diff_check_command.dart';
import '../plugins/tdd/commands/doctor_command.dart';
import '../plugins/tdd/commands/fake_command.dart';
import '../plugins/tdd/commands/func_command.dart';
import '../plugins/tdd/commands/gen_command.dart';
import '../plugins/tdd/commands/init_command.dart';
import '../plugins/tdd/commands/make_command.dart';
import '../plugins/tdd/commands/migrate_paths_command.dart';
import '../plugins/tdd/commands/plan_command.dart';
import '../plugins/tdd/commands/replay_command.dart';
import '../plugins/tdd/commands/realize_command.dart';
import '../plugins/tdd/commands/realize_mock_command.dart';
import '../plugins/tdd/commands/refactor_command.dart';
import '../plugins/tdd/commands/referee_command.dart';
import '../plugins/tdd/commands/reset_command.dart';
import '../plugins/tdd/commands/run_command.dart';
import '../plugins/tdd/commands/verify_command.dart';
import '../plugins/tdd/commands/verify_red_command.dart';
import '../plugins/tdd/commands/view_command.dart';
import '../plugins/tdd/commands/wire_command.dart';
import '../plugins/tdd/tdd_plugin.dart';

class TddCommand extends Command<void> {
  TddCommand(this.plugin) {
    addSubcommand(InitCommand(plugin));
    addSubcommand(PlanCommand(plugin));
    addSubcommand(GenCommand(plugin));
    addSubcommand(FakeCommand(plugin));
    addSubcommand(VerifyRedCommand(plugin));
    addSubcommand(MakeCommand(plugin));
    addSubcommand(WireCommand(plugin));
    addSubcommand(ComposeCommand(plugin));
    addSubcommand(FuncCommand(plugin));
    addSubcommand(ViewCommand(plugin));
    addSubcommand(RefactorCommand(plugin));
    addSubcommand(RunCommand(plugin));
    addSubcommand(ReplayCommand(plugin));
    addSubcommand(VerifyCommand(plugin));
    addSubcommand(MigratePathsCommand(plugin));
    addSubcommand(CorpusCommand(plugin));
    addSubcommand(RefereeCommand(plugin));
    addSubcommand(DiffCheckCommand(plugin));
    addSubcommand(ResetCommand(plugin));
    addSubcommand(DoctorCommand(plugin));
    addSubcommand(RealizeCommand(plugin));
    addSubcommand(RealizeMockCommand(plugin));
  }

  final TddPlugin plugin;

  @override
  String get name => 'tdd';

  @override
  String get description =>
      'Drive the full TDD red-green-refactor cycle (init, plan, gen, '
      'verify-red, make, wire, func, refactor, run, verify). See '
      'specs/041-tdd-setup-plugin/spec.md for the full contract.';

  @override
  String get invocation => 'zfa tdd <subcommand> [options]';

  @override
  Future<void> run() async {
    printUsage();
  }
}
