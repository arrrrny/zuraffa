/// `zfa tdd corpus status` — read-only corpus state at a glance: per-state
/// feature counts, the resume point, gate outcomes, and ledger totals
/// (spec 051-corpus-harness, FR-009).
///
/// Skeleton (T001): the aggregation lands with the Phase 7 tasks.
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class CorpusStatusCommand extends Command<void> {
  CorpusStatusCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report corpus state read-only: per-state counts, resume point, '
      'ledger totals (spec 051, FR-009).';

  @override
  String get invocation => 'zfa tdd corpus status [--project <dir>]';

  @override
  Future<void> run() async {
    // T001 skeleton: the aggregation arrives with spec 051 Phase 7 (T028).
    printUsage();
  }
}
