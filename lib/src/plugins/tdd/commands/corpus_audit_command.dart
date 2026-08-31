/// `zfa tdd corpus audit` — attribute every file under the driven app's
/// `lib/` to a recorded zfa command invocation (loop cycle logs' artifact
/// registries, setup/import provenance) or a carve-out manifest entry
/// (spec 051-corpus-harness, FR-005/FR-006).
///
/// Skeleton (T001): the scanner + report land with the Phase 6 tasks.
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class CorpusAuditCommand extends Command<void> {
  CorpusAuditCommand(this.plugin) {
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
  String get name => 'audit';

  @override
  String get description =>
      'Attribute every lib/ file to a recorded zfa invocation or carve-out '
      'entry; unattributed files fail by name (spec 051, FR-005/FR-006).';

  @override
  String get invocation => 'zfa tdd corpus audit [--project <dir>]';

  @override
  Future<void> run() async {
    // T001 skeleton: the scanner arrives with spec 051 Phase 6 (T024/T026).
    printUsage();
  }
}
