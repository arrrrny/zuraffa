/// `zfa tdd run <feature>` — NOT YET IMPLEMENTED (Phase 10, T070-T076).
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class RunCommand extends Command<void> {
  RunCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive the full cycle for a feature (NOT YET IMPLEMENTED — see '
      'tasks T070-T076).';

  @override
  String get invocation => 'zfa tdd run <feature>';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd run: not yet implemented (Phase 10 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T070-T076).',
    );
  }
}
