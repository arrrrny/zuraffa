/// `zfa tdd make <behavior-id>` — NOT YET IMPLEMENTED (Phase 8, T062-T065).
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class MakeCommand extends Command<void> {
  MakeCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'make';

  @override
  String get description =>
      'Generate minimal implementation via zfa make/entity create/build, '
      'run the target test green (NOT YET IMPLEMENTED — see tasks '
      'T062-T065).';

  @override
  String get invocation => 'zfa tdd make <behavior-id>';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd make: not yet implemented (Phase 8 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T062-T065).',
    );
  }
}
