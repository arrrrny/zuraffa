/// `zfa tdd prove <feature>` — the incremental re-proving delta (spec
/// 1113-unified-tdd-journal, issue #1113; the #1013 LOOP-RUNTIME exit
/// criterion).
///
/// Walks the feature's journal through [JournalReader] and computes the
/// delta: **what behaviors are ungated since the last prove?** — only
/// those behaviors need re-proving. Incremental, not a full re-run:
///
/// - A behavior is **gated** when it has green evidence AND its
///   registered subject/test files match the fingerprints the LAST
///   prove entry recorded.
/// - A behavior is **ungated** when it has no green evidence at all
///   (`no-evidence`), when it registered after the last prove
///   (`not-proven`), or when its files changed since the last prove
///   (`subject-changed` / `test-changed` — a file appearing or
///   disappearing is a change; sha256 per file).
/// - The FIRST prove on a feature is the baseline: every behavior with
///   green evidence is gated, and the prove entry records the
///   fingerprints the NEXT prove walks.
///
/// Every prove invocation journals its own entry (cycle=meta,
/// phase=prove) carrying the fresh fingerprints and the reported
/// ungated ids — the journal is the memory the delta reads, so prove
/// never re-walks files older than the last prove.
///
/// Machine contract: `prove: feature=<f> behaviors=<n> gated=<n>
/// ungated=<n> result=<baseline|clean|delta>` (+ ` last_prove_at=<ts>`
/// when a prior prove exists), one `ungated: <id> — <reason>` line per
/// ungated behavior. Exit 0 iff zero ungated behaviors (nothing to
/// re-prove), 1 when the delta is non-empty, 2 misfire (no feature
/// directory). Reads the journal EXCLUSIVELY through [JournalReader] —
/// no journal file I/O here.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../services/journal.dart';
import '../tdd_plugin.dart';
import 'run_driver_core.dart';

class ProveCommand extends Command<void> {
  ProveCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory '
          'is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'prove';

  @override
  String get description =>
      'Walk the feature\'s unified journal and compute the incremental '
      're-proving delta — the behaviors ungated since the last prove '
      '(no green evidence, or files changed since the last prove\'s '
      'fingerprints). Only those behaviors need re-proving; prove itself '
      'runs nothing. Exit 0 iff zero ungated (spec 1113, issue #1113).';

  @override
  String get invocation => 'zfa tdd prove <feature> [--project <dir>]';

  static const _exitDelta = 1;
  static const _exitRunnerError = 2;

  @override
  Future<void> run() async {
    const label = 'prove';
    final startedAt = DateTime.now().toUtc().toIso8601String();
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose journal to walk '
        '(e.g. 004-login-ui)',
        invocation,
      );
    }
    final feature = stripSpecsPrefix(rest.first);
    validateFeatureSegment(feature, invocation);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? projectFlag
        : ProjectRoot.find(anchorDir: 'specs');

    final featureDir = p.join(projectRoot, 'specs', feature);
    if (!await Directory(featureDir).exists()) {
      print(
        'zfa tdd $label: no feature directory at '
        '${p.relative(featureDir, from: projectRoot)} (project root: '
        '$projectRoot)',
      );
      exitCode = _exitRunnerError;
      return;
    }

    // The one canonical stream — no journal file I/O in this command.
    final journal = await const JournalReader().read(
      feature: feature,
      projectRoot: projectRoot,
    );
    final lastProve = journal.lastProve;
    final baseline = lastProve?.fingerprints;

    // ---------------------------------------------------------------
    // The delta walk: every REGISTERED behavior, gated or ungated.
    // ---------------------------------------------------------------
    final ungated = <({String id, String reason})>[];
    final fingerprints = <String, Map<String, String?>>{};
    var gated = 0;
    for (final behavior in journal.behaviors) {
      final subject = await journalFileFingerprint(
        _resolve(behavior.subjectPath, projectRoot),
      );
      final test = await journalFileFingerprint(
        _resolve(behavior.testPath, projectRoot),
      );
      fingerprints[behavior.id] = {'subject': subject, 'test': test};

      if (!journal.greenEvidence.containsKey(behavior.id)) {
        ungated.add((
          id: behavior.id,
          reason:
              'no green evidence in the cycle log — the behavior was '
              'never driven green',
        ));
        continue;
      }
      if (baseline == null) {
        // First prove: the baseline. Evidence stands until files change.
        gated++;
        continue;
      }
      final recorded = baseline[behavior.id];
      if (recorded == null) {
        ungated.add((
          id: behavior.id,
          reason: 'registered after the last prove — never baselined',
        ));
        continue;
      }
      if (recorded['subject'] != subject || recorded['test'] != test) {
        final changed = <String>[
          if (recorded['subject'] != subject) 'subject',
          if (recorded['test'] != test) 'test',
        ].join(' and ');
        ungated.add((
          id: behavior.id,
          reason:
              '$changed changed since the last prove '
              '(${lastProve?.finishedAt})',
        ));
        continue;
      }
      gated++;
    }

    // ---------------------------------------------------------------
    // The verdict + the machine contract lines.
    // ---------------------------------------------------------------
    final result = baseline == null
        ? 'baseline'
        : ungated.isEmpty
        ? 'clean'
        : 'delta';
    final gateState = journal.greenEvidence.isEmpty
        ? 'not_assessed'
        : ungated.isEmpty
        ? 'green'
        : 'red';

    print(
      'prove: feature=$feature behaviors=${journal.behaviors.length} '
      'gated=$gated ungated=${ungated.length} result=$result'
      '${lastProve != null ? ' last_prove_at=${lastProve.finishedAt}' : ''}',
    );
    for (final entry in ungated) {
      print('ungated: ${entry.id} — ${entry.reason}');
    }
    if (ungated.isNotEmpty) {
      print(
        '   ${ungated.length} behavior(s) need re-proving — run '
        '`zfa tdd run $feature` (the driver resumes at the ungated '
        'behaviors), then re-run prove.',
      );
    }

    // ---------------------------------------------------------------
    // The prove entry: the journal is the delta's memory — the fresh
    // fingerprints and the reported ungated ids ride the entry the NEXT
    // prove walks.
    // ---------------------------------------------------------------
    final writer = JournalWriter(featureDir);
    final refs = await writer.resolveRefs();
    await writer.append(
      JournalEntry(
        feature: feature,
        cycle: 'meta',
        phase: 'prove',
        startedAt: startedAt,
        finishedAt: DateTime.now().toUtc().toIso8601String(),
        gateState: gateState,
        receipts: [
          if (refs.engine != null) refs.engine!,
          if (refs.skin != null) refs.skin!,
        ],
        violations: [
          for (final entry in ungated) 'ungated: ${entry.id} — ${entry.reason}',
        ],
        engineReceipt: refs.engine,
        skinReceipt: refs.skin,
        contractSchema: refs.contract,
        result: result,
        behaviors: [for (final b in journal.behaviors) b.id],
        fingerprints: fingerprints,
        ungated: [for (final entry in ungated) entry.id],
      ),
    );

    exitCode = ungated.isEmpty ? 0 : _exitDelta;
  }

  /// Registry paths are absolute or project-relative — resolve against
  /// the project root either way.
  static String? _resolve(String? path, String projectRoot) {
    if (path == null || path.isEmpty) return null;
    if (p.isAbsolute(path)) return path;
    return p.join(projectRoot, path);
  }
}
