/// `zfa tdd verify` — NOT YET IMPLEMENTED (Phase 11, T077-T081).
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class VerifyCommand extends Command<void> {
  VerifyCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Audit coverage and mutation strength (NOT YET IMPLEMENTED — see '
      'tasks T077-T081).';

  @override
  String get invocation => 'zfa tdd verify';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd verify: not yet implemented (Phase 11 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T077-T081).',
    );
  }
}
