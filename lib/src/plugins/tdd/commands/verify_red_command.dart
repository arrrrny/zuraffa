/// `zfa tdd verify-red` — NOT YET IMPLEMENTED (Phase 7, T055-T061).
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class VerifyRedCommand extends Command<void> {
  VerifyRedCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'verify-red';

  @override
  String get description =>
      'Assert the target test fails with an assertion failure and append '
      'red evidence (NOT YET IMPLEMENTED — see tasks T055-T061).';

  @override
  String get invocation => 'zfa tdd verify-red';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd verify-red: not yet implemented (Phase 7 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T055-T061).',
    );
  }
}
