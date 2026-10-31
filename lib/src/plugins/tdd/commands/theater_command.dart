/// `zfa tdd theater <feature>` — tombstone for the verb that moved to the
/// `zuraffa_tui` companion package (issue #393, the nocterm removal).
///
/// The replay TUI is no longer core: `1c742954` deleted the nocterm runtime
/// and the command with it, leaving this verb's spec-917 golden row
/// (`test/commands/tdd_json_stream_test.dart`) pinning an envelope the
/// parser could never reach — `zfa tdd theater --json` died on the `tdd`
/// level with "Could not find an option named --json" and a text-only usage
/// dump, and master's conformance gate went red with it.
///
/// The stub keeps the verb registered so an old invocation gets the
/// migration message instead of that dump, and — per SPEC 917's "errors are
/// an API" — still closes with the canonical verdict envelope under
/// `--json` (the golden row passes unchanged). It opens nothing and reads
/// nothing: the successor command lives in the companion package.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../cli/exit_protocol.dart';
import '../models/verdict_envelope.dart';
import '../services/verdict_emitter.dart';

/// The successor invocation, named in every exit path (text fix line and
/// JSON envelope alike).
const String _successor = 'dart run zuraffa_tui:zuraffa_tui theater';

class TheaterCommand extends Command<void> {
  TheaterCommand() {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Accepted for verb compatibility with the pre-#393 surface; the '
          'successor command reads the project itself.',
    );
  }

  @override
  String get name => 'theater';

  @override
  String get description =>
      'Tombstone: the journal replay TUI moved to the zuraffa_tui '
      'companion (#393) — redirects, never opens a TUI in core.';

  @override
  String get invocation =>
      'zfa tdd theater [--json] [--project <path>] [<feature>]';

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    print(
      'zfa tdd theater: the journal replay TUI moved to the zuraffa_tui '
      'companion package (#393) — core no longer ships the TUI runtime '
      '(the nocterm removal).',
    );
    print('Run it there instead: $_successor [<feature>]');
    _verdict
      ..outcome = VerdictOutcome.stopped
      ..exitClass = 'moved'
      ..fix =
          'add the companion (`dart pub add zuraffa_tui`) and re-run as '
          '`$_successor <feature>`'
      ..details['successor'] = _successor;
    // VISION §4: every non-zero exit ends with the machine-actionable
    // fix line (JSON mode carries it in the envelope instead).
    print(ExitProtocol.fixLine(_verdict.fix!));
    exitCode = 1;
  }
}
