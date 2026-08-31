/// `zfa tdd corpus run` — drive every `ready` feature in the corpus
/// manifest through `zfa tdd run` then `zfa tdd verify`, in manifest
/// order, persisting corpus progress after every feature and resuming
/// from the first incomplete feature (spec 051-corpus-harness, FR-001).
///
/// Skeleton (T001): the driving loop lands with the Phase 3 tasks.
library;

import 'package:args/command_runner.dart';

import '../tdd_plugin.dart';

class CorpusRunCommand extends Command<void> {
  CorpusRunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root of the driven app (containing .zfa/, specs/, lib/). '
          'When omitted, the current working directory is used. The runner '
          'never mutates the process-global working directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the per-feature '
          '`tdd run` / `tdd verify` commands (defaults to this package\'s '
          'bin/zfa.dart). Point this at a scripted fake to drive the corpus '
          'against stubbed features.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every ready manifest feature through run then verify in '
      'manifest order, stopping on the first roadblock (spec 051, '
      'FR-001..FR-004).';

  @override
  String get invocation =>
      'zfa tdd corpus run [--project <dir>] [--zfa-bin <path>]';

  @override
  Future<void> run() async {
    // T001 skeleton: the loop arrives with spec 051 Phase 3 (T015).
    printUsage();
  }
}
