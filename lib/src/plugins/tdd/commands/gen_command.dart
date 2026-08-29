/// `zfa tdd gen <behavior-id>` — NOT YET IMPLEMENTED (Phase 6, T051-T054).
/// Honest misfire-stop stub per FR-031.
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class GenCommand extends Command<void> {
  GenCommand(this.plugin);

  final TddPlugin plugin;

  @override
  String get name => 'gen';

  @override
  String get description =>
      'Generate a failing test + compiling source stub for a behavior '
      '(NOT YET IMPLEMENTED — see tasks T051-T054).';

  @override
  String get invocation => 'zfa tdd gen <behavior-id>';

  @override
  Future<void> run() async {
    throw StateError(
      'zfa tdd gen: not yet implemented (Phase 6 of '
      'specs/041-tdd-setup-plugin/tasks.md, tasks T051-T054). The current '
      'PR lands Phase 1 (skeleton), Phase 2 (writers), Phase 3 (US1 setup '
      'baseline), Phase 4 (US2 init), and Phase 5 (US3 plan). '
      'Gen/verify-red/make/refactor/run/verify land in a follow-up.',
    );
  }
}
