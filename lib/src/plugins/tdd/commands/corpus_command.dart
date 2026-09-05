/// `zfa tdd corpus` — the corpus-level orchestrator family (spec
/// 051-corpus-harness): batch driving with resume (`run`), read-only
/// status (`status`), the provenance audit (`audit`), and the
/// generator behavioral differential gate (`differential`, bug #805).
///
/// The parent command only registers the subcommands; each lives in
/// its own file with its own contract (see
/// specs/051-corpus-harness/contracts/corpus-harness.md).
library;

import 'package:args/command_runner.dart';

import '../models/verdict_envelope.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import 'corpus_audit_command.dart';
import 'corpus_differential_command.dart';
import 'corpus_run_command.dart';
import 'corpus_status_command.dart';

class CorpusCommand extends Command<void> {
  CorpusCommand(this.plugin) {
    addSubcommand(CorpusRunCommand(plugin));
    addSubcommand(CorpusStatusCommand(plugin));
    addSubcommand(CorpusAuditCommand(plugin));
    addSubcommand(CorpusDifferentialCommand(plugin));
  }

  final TddPlugin plugin;

  /// Issue #969: parents emit a usage envelope too — zero lying
  /// surfaces means every verb answers the --json contract.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'corpus';

  @override
  String get description =>
      'Drive the whole spec corpus through the TDD loop: batch run with '
      'resume, per-feature verify gate, provenance audit, and the gap '
      'ledger (spec 051).';

  @override
  String get invocation => 'zfa tdd corpus <subcommand> [options]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    _verdict
      ..outcome = VerdictOutcome.stopped
      ..exitClass = 'usage';
    printUsage();
  }
}
