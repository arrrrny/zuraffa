/// `zfa tdd init` — idempotently ensure the Part-1 TDD environment exists.
///
/// Spec 1528 (issue #1528): the writer sequence moved VERBATIM into
/// `TddBaselineInit` (services/baseline_init.dart) so the `zfa tdd run` /
/// `zfa tdd gen` entry preflight executes the SAME idempotent sequence.
/// This command's observable behavior is byte-identical: the service
/// prints the same lines through the stdout/stderr sinks and throws the
/// same misfire StateError.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/baseline_init.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class InitCommand extends Command<void> {
  InitCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root to initialize the TDD baseline in. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help:
          'Overwrite existing baseline files whose content differs from what '
          'the writers would generate. Without --force, `zfa tdd init` is '
          'strictly idempotent and refuses to clobber a file that was hand '
          'edited or generated under a different profile (e.g. Dart vs '
          'Flutter). With --force, those files are replaced in place.',
      negatable: false,
    );
    argParser.addFlag(
      'skin',
      help:
          'Opt into the SKIN lane (issue #1260): also adds the skin lane\'s '
          'CERTIFIED dependency — `zuraffa_ui: ^0.1.0`, the identified '
          'Zfa* vocabulary whose ZuraffaApp is the certified app shell — '
          'to the project pubspec under dependencies: (runtime, not dev). '
          'Refuses loudly on pure-Dart targets (zuraffa_ui is a Flutter '
          'SDK package).',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'init';

  @override
  String get description =>
      'Idempotently ensure the TDD baseline exists in the current project '
      '(test/, dart_test.yaml, .specify/memory/tdd-profile.md, testing '
      'dev_dependencies).';

  @override
  String get invocation => 'zfa tdd init';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final force = argResults?['force'] == true;
    // Issue #1260 remediation 2: skin-lane opt-in — the certified
    // dependency is added to the project's dependencies: (runtime).
    final skin = argResults?['skin'] == true;

    // Spec 1528: the shared idempotent writer sequence (TddBaselineInit) —
    // identical stdout/stderr output, identical misfire StateError.
    await const TddBaselineInit().ensure(
      projectRoot: cwd,
      force: force,
      skin: skin,
      onLine: stdout.writeln,
      onError: stderr.writeln,
    );
    _verdict.details['failures'] = 0;
  }
}
