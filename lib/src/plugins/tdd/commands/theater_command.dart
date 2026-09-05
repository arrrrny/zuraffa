/// `zfa tdd theater <feature>` — the read-only replay TUI for the TDD
/// journal (spec 1006, issue #1006).
///
/// Opens a three-pane terminal UI (nocterm) visualizing the receipts and
/// the cycle-log for one feature:
///
///  - left: spec annotation cards, scrollable, click to expand;
///  - right: the cycle-log timeline; click a cycle → the evidence diff,
///    click a behavior → its receipt (action, evidence, file);
///  - bottom: the live status line; `[?]` opens the classifier verdict.
///
/// Read-only by construction: everything is derived from
/// `.zfa/receipts/` and `specs/<feature>/tdd/` — no mutation, no
/// separate state. On a non-TTY stdout (CI, piped output) the command
/// refuses to start the TUI with an actionable message and exits 1 —
/// the same discipline the tui plugin's `TtyGuard` applies (FR-009 of
/// 017-tui-plugin) — after printing the machine summary line.
///
/// The machine contract is the summary line
/// `theater: feature=<f> behaviors=<n> cycles=<m> receipts=<k>
/// result=<opened|non-tty|error>` as the final stdout line on every
/// code path; on a TTY it is printed after the TUI closes.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:path/path.dart' as p;

import '../services/theater_data.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';
import '../widgets/theater_screen.dart';

/// Outcome labels for the machine-readable summary line.
enum TheaterOutcome {
  opened('opened'),
  nonTty('non-tty'),
  error('error');

  const TheaterOutcome(this.label);
  final String label;
}

class TheaterCommand extends Command<void> {
  TheaterCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'The project root (default: nearest pubspec.yaml or specs/ '
          'walk-up)',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'theater';

  @override
  String get description =>
      'Open the read-only replay TUI for a feature\'s TDD journal: '
      'receipts + cycle-log rendered as a three-pane terminal UI '
      '(spec 1006, issue #1006).';

  @override
  String get invocation => 'zfa tdd theater <feature> [--project <dir>]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature id is required: zfa tdd theater <feature>');
    }
    final featureArg = rest.first;

    // Feature resolution mirrors `zfa tdd replay`: strip an optional
    // `specs/` prefix, validate a single directory segment, resolve the
    // project root.
    var feature = featureArg;
    if (feature.startsWith('specs/')) {
      final tail = feature.substring('specs/'.length);
      if (tail.isNotEmpty) feature = tail;
    }
    if (feature.contains('/') ||
        feature.contains(r'\') ||
        feature == '.' ||
        feature == '..') {
      usageException(
        'invalid feature "$featureArg": expected a single spec directory '
        'name such as 004-login-ui, not a path.',
      );
    }
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.normalize(p.absolute(projectFlag))
        : ProjectRoot.find(anchorDir: 'specs');

    // Load the journal (read-only). Load failures are honest errors:
    // unknown feature, missing registry.
    final TheaterSnapshot snapshot;
    try {
      snapshot = await TheaterData.load(
        feature: feature,
        projectRoot: projectRoot,
      );
    } on TheaterException catch (e) {
      print('zfa tdd theater: ${e.message}');
      _printSummary(
        feature: feature,
        snapshot: null,
        outcome: TheaterOutcome.error,
      );
      exitCode = 1;
      return;
    }

    // The TTY guard (the tui plugin's FR-009 discipline): a TUI cannot
    // render on piped/redirected stdout — refuse with an actionable
    // message instead of hanging or corrupting output.
    final isTty = stdout.supportsAnsiEscapes && stdout.hasTerminal;
    if (!isTty) {
      print(
        'zfa tdd theater: ${snapshot.behaviors.length} behavior(s) loaded '
        'for $feature, but the TUI requires an interactive terminal '
        '(TTY). Detected non-TTY stdout (piped or redirected). Run '
        '`zfa tdd theater $feature` from a real terminal.',
      );
      _printSummary(
        feature: feature,
        snapshot: snapshot,
        outcome: TheaterOutcome.nonTty,
      );
      exitCode = 1;
      return;
    }

    // Open the theater. nocterm owns the terminal; the summary line is
    // printed after the TUI closes (the machine contract's final
    // stdout line).
    try {
      await nocterm.runApp(
        TheaterScreen(snapshot: snapshot),
        enableHotReload: false,
      );
    } catch (error) {
      print('zfa tdd theater: the TUI engine failed to start: $error');
      _printSummary(
        feature: feature,
        snapshot: snapshot,
        outcome: TheaterOutcome.error,
      );
      exitCode = 1;
      return;
    }
    _printSummary(
      feature: feature,
      snapshot: snapshot,
      outcome: TheaterOutcome.opened,
    );
  }

  void _printSummary({
    required String feature,
    required TheaterSnapshot? snapshot,
    required TheaterOutcome outcome,
  }) {
    print(
      'theater: feature=$feature '
      'behaviors=${snapshot?.behaviors.length ?? 0} '
      'cycles=${snapshot?.cycles.length ?? 0} '
      'receipts=${snapshot?.receiptCount ?? 0} '
      'result=${outcome.label}',
    );
  }
}
