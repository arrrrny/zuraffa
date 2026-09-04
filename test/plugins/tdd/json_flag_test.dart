/// Unit tests for --json flag registration on all 22+ leaf TDD
/// commands (issue #964, FR-2).
library;

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/plan_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/gen_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/make_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/view_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/verify_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/verify_red_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/init_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/compose_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/refactor_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/reset_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/wire_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/fake_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/func_command.dart';

/// Asserts that [command]'s argParser has a `json` flag and it defaults
/// to false (the human-readable output remains the default).
void _expectJsonFlag(Command<void> command, String name) {
  final flag = command.argParser.options['json'];
  expect(flag, isNotNull, reason: '$name: --json flag must be registered');
  expect(flag!.defaultsTo, isFalse, reason: '$name: --json must default to false');
  expect(flag.isFlag, isTrue, reason: '$name: --json must be a flag, not an option');
}

void main() {
  // The plugin is required to construct every command; we construct it
  // once and reuse the instance to avoid duplicate `addCommand` errors.
  final plugin = TddPlugin();

  group('U4..U21: --json flag registration on TDD leaf commands', () {
    test('U4: RunCommand has --json flag', () {
      _expectJsonFlag(RunCommand(plugin), 'run');
    });
    test('U5: GenCommand has --json flag', () {
      _expectJsonFlag(GenCommand(plugin), 'gen');
    });
    test('U6: MakeCommand has --json flag', () {
      _expectJsonFlag(MakeCommand(plugin), 'make');
    });
    test('U7: ViewCommand has --json flag', () {
      _expectJsonFlag(ViewCommand(plugin), 'view');
    });
    test('U8: PlanCommand has --json flag', () {
      _expectJsonFlag(PlanCommand(plugin), 'plan');
    });
    test('U9: ResetCommand has --json flag', () {
      _expectJsonFlag(ResetCommand(plugin), 'reset');
    });
    test('U10: RealizeCommand has --json flag', () {
      _expectJsonFlag(RealizeCommand(plugin), 'realize');
    });
    test('U11: VerifyCommand has --json flag', () {
      _expectJsonFlag(VerifyCommand(plugin), 'verify');
    });
    test('U12: VerifyRedCommand has --json flag', () {
      _expectJsonFlag(VerifyRedCommand(plugin), 'verify-red');
    });
    test('U13: InitCommand has --json flag', () {
      _expectJsonFlag(InitCommand(plugin), 'init');
    });
    test('U14: ComposeCommand has --json flag', () {
      _expectJsonFlag(ComposeCommand(plugin), 'compose');
    });
    test('U15: RefactorCommand has --json flag', () {
      _expectJsonFlag(RefactorCommand(plugin), 'refactor');
    });
    test('U16: WireCommand has --json flag', () {
      _expectJsonFlag(WireCommand(plugin), 'wire');
    });
    test('U17: FakeCommand has --json flag', () {
      _expectJsonFlag(FakeCommand(plugin), 'fake');
    });
    test('U18: FuncCommand has --json flag', () {
      _expectJsonFlag(FuncCommand(plugin), 'func');
    });
  });
}
