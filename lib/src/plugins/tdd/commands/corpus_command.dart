/// `zfa tdd corpus` — top-level corpus orchestrator (spec 051).
///
/// Subcommands:
/// - `run` — drive every ready feature through run→verify
/// - `audit` — attribute every lib/ file to a zfa invocation
/// - `status` — report corpus state without driving
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/corpus_manifest.dart';
import '../models/corpus_feature_progress.dart';
import '../services/corpus_progress_store.dart';
import '../services/corpus_runner.dart';
import '../services/gap_ledger.dart';
import '../services/provenance_auditor.dart';
import '../tdd_plugin.dart';

class CorpusCommand extends Command<void> {
  CorpusCommand(this.plugin) {
    addSubcommand(CorpusRunCommand(plugin));
    addSubcommand(CorpusAuditCommand(plugin));
    addSubcommand(CorpusStatusCommand(plugin));
  }

  final TddPlugin plugin;

  @override
  String get name => 'corpus';

  @override
  String get description =>
      'Corpus-level orchestrator: drive, audit, and status for TDD features.';

  @override
  String get invocation => 'zfa tdd corpus <run|audit|status> [options]';
}

/// `zfa tdd corpus run` — drive the corpus.
class CorpusRunCommand extends Command<void> {
  CorpusRunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root. Defaults to CWD.',
    );
    argParser.addOption(
      'zfa-bin',
      help: 'Path to the zfa CLI entrypoint for spawning per-feature commands.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every ready feature through zfa tdd run then zfa tdd verify, '
      'with resume and gap ledger.';

  @override
  String get invocation => 'zfa tdd corpus run [--project <dir>]';

  @override
  Future<void> run() async {
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final zfaBin = argResults?['zfa-bin'] as String?;

    // Load manifest.
    final manifest = await CorpusManifest.read(projectRoot);
    if (manifest == null) {
      stderr.writeln(
        'zfa tdd corpus run: no corpus manifest at '
        '${p.join(projectRoot, ".zfa", "manifests", "corpus-manifest.json")}. '
        'Run `zfa corpus import` first.',
      );
      exitCode = 2;
      return;
    }

    final features = manifest.features;
    final readiness = {
      for (final f in features) f.name: f.ready,
    };
    final featureNames = features.map((f) => f.name).toList();

    final store = CorpusProgressStore(projectRoot);
    final ledger = GapLedger(projectRoot);

    // Check concurrent run.
    final existing = await store.load();
    final refusal = store.refusalReason(existing);
    if (refusal != null) {
      stderr.writeln('zfa tdd corpus run: $refusal');
      exitCode = 4;
      return;
    }

    final runner = CorpusRunner(
      projectRoot: projectRoot,
      progressStore: store,
      gapLedger: ledger,
      zfaBin: zfaBin,
    );

    final outcomes = await runner.run(
      manifestFeatures: featureNames,
      readiness: readiness,
    );

    // Print per-feature lines.
    for (final o in outcomes) {
      final stateStr = switch (o.state) {
        CorpusFeatureState.done => 'done (gate=${o.gateOutcome})',
        CorpusFeatureState.stopped => 'stopped (${o.stoppedAt ?? "unknown"})',
        CorpusFeatureState.notReady => 'skipped (not-ready)',
        CorpusFeatureState.waived => 'waived',
        _ => o.state.name,
      };
      stdout.writeln('corpus run: ${o.name} -> $stateStr');
    }

    // Summary.
    var done = 0;
    var stopped = 0;
    var waived = 0;
    var skipped = 0;
    var pending = 0;
    for (final o in outcomes) {
      switch (o.state) {
        case CorpusFeatureState.done:
          done++;
        case CorpusFeatureState.stopped:
          stopped++;
        case CorpusFeatureState.waived:
          waived++;
        case CorpusFeatureState.notReady:
          skipped++;
        default:
          pending++;
      }
    }

    final resume = store.resumePoint(featureNames, {
      for (final o in outcomes) o.name: CorpusFeatureProgress(
        name: o.name,
        state: o.state,
      ),
    });

    stdout.writeln(
      'corpus run: done=$done stopped=$stopped waived=$waived '
      'skipped=$skipped pending=$pending total=${featureNames.length} '
      'resume=${resume ?? "none"}',
    );

    if (stopped > 0) {
      exitCode = 1;
    }
  }
}

/// `zfa tdd corpus audit` — attribute lib/ files.
class CorpusAuditCommand extends Command<void> {
  CorpusAuditCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root. Defaults to CWD.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'audit';

  @override
  String get description =>
      'Attribute every lib/ file to a zfa invocation or carve-out entry.';

  @override
  String get invocation => 'zfa tdd corpus audit [--project <dir>]';

  @override
  Future<void> run() async {
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;

    final auditor = ProvenanceAuditor(projectRoot: projectRoot);
    final result = await auditor.audit();
    await auditor.writeReport(result);

    // Per-file lines.
    for (final r in result.attributed) {
      stdout.writeln(
        'corpus audit: ${r.filePath} attributed (${r.source.name}: ${r.invocation})',
      );
    }
    for (final r in result.carveOut) {
      stdout.writeln(
        'corpus audit: ${r.filePath} attributed (carve-out: ${r.invocation})',
      );
    }
    for (final f in result.unattributed) {
      stdout.writeln('corpus audit: $f UNATTRIBUTED');
    }

    // Summary.
    stdout.writeln(
      'corpus audit: attributed=${result.attributed.length} '
      'carve-out=${result.carveOut.length} '
      'unattributed=${result.unattributed.length} '
      'total=${result.total}',
    );

    if (!result.isComplete) {
      exitCode = 1;
    }
  }
}

/// `zfa tdd corpus status` — report corpus state.
class CorpusStatusCommand extends Command<void> {
  CorpusStatusCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Project root. Defaults to CWD.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'status';

  @override
  String get description =>
      'Report per-state counts, resume point, and ledger totals read-only.';

  @override
  String get invocation => 'zfa tdd corpus status [--project <dir>]';

  @override
  Future<void> run() async {
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;

    // Load manifest.
    final manifest = await CorpusManifest.read(projectRoot);
    if (manifest == null) {
      stderr.writeln(
        'zfa tdd corpus status: no corpus manifest at '
        '${p.join(projectRoot, ".zfa", "manifests", "corpus-manifest.json")}.',
      );
      exitCode = 2;
      return;
    }

    final featureNames = manifest.features.map((f) => f.name).toList();

    final store = CorpusProgressStore(projectRoot);
    final progress = await store.load() ?? CorpusProgress();
    final ledger = GapLedger(projectRoot);
    final entries = await ledger.load();
    final totals = ledger.totals(entries);

    // Per-feature status.
    for (final name in featureNames) {
      final p = progress.features[name];
      final state = p?.state ?? CorpusFeatureState.pending;
      final stateStr = switch (state) {
        CorpusFeatureState.done => 'done (gate=${p?.gateOutcome ?? "?"})',
        CorpusFeatureState.stopped => 'stopped (${p?.gateOutcome ?? "?"})',
        CorpusFeatureState.waived =>
          'waived (reason="${p?.waived?.reason ?? "?"}")',
        CorpusFeatureState.notReady => 'not-ready',
        CorpusFeatureState.dropped => 'dropped',
        _ => 'pending',
      };
      final gapCount = entries
          .where((e) => e.feature == name && e.resolution == null)
          .length;
      final gapStr =
          gapCount > 0 ? ' — $gapCount unresolved gap${gapCount > 1 ? "s" : ""}' : '';
      stdout.writeln('corpus status: $name $stateStr$gapStr');
    }

    // Compute counts.
    var done = 0;
    var stopped = 0;
    var waived = 0;
    var pending = 0;
    var notReady = 0;
    var dropped = 0;
    for (final name in featureNames) {
      final p = progress.features[name];
      final state = p?.state ?? CorpusFeatureState.pending;
      switch (state) {
        case CorpusFeatureState.done:
          done++;
        case CorpusFeatureState.stopped:
          stopped++;
        case CorpusFeatureState.waived:
          waived++;
        case CorpusFeatureState.notReady:
          notReady++;
        case CorpusFeatureState.dropped:
          dropped++;
        default:
          pending++;
      }
    }

    final resume = store.resumePoint(featureNames, progress.features);

    stdout.writeln(
      'corpus status: done=$done stopped=$stopped waived=$waived '
      'pending=$pending not_ready=$notReady dropped=$dropped '
      'total=${featureNames.length} gaps=${totals.total} '
      'unresolved=${totals.unresolved} resume=${resume ?? "none"}',
    );

    // Exit 0 only when all manifest features are done+gated.
    final allDone = done + waived + notReady == featureNames.length;
    if (!allDone) {
      exitCode = 1;
    }
  }
}
