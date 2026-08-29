/// `zfa tdd refactor` — NOT YET IMPLEMENTED (Phase 9, T066-T069).
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class RefactorCommand extends Command<void> {
  RefactorCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'refactor';

  @override
  String get description =>
      'Refactor on a green suite only; never edit tests (NOT YET '
      'IMPLEMENTED — see tasks T066-T069).';

  @override
  String get invocation => 'zfa tdd refactor';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd refactor: not yet implemented (Phase 9 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T066-T069).',
    );
  }
}
