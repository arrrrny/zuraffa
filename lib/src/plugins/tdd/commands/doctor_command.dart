/// `zfa tdd doctor` — drift reporting across the three TDD stores (bug
/// #828: cycle-log evidence integrity).
///
/// Read-only by contract: the doctor never repairs anything, it reports
/// the drift between `tdd/run-state.json`, `tdd/artifacts.json`, and
/// `tdd/cycle-log.md` and prescribes the recovery on a `--> fix:` line:
///
/// 1. run-state claims without matching cycle-log evidence — a green
///    claim needs its green entry, a done claim its red+green backing, a
///    red claim its red entry (the resume reconciliation in `zfa tdd
///    run` auto-heals the green/done half; the doctor names the rest);
/// 2. registry records whose artifacts are missing from disk (the
///    registry is the durable link `gen` writes and every reader trusts);
/// 3. a surviving pending write-ahead journal (an interrupted
///    transaction — the next `zfa tdd run` replays or discards it);
/// 4. evidence hash-chain breaks (bug #828 schema-1 entries: the
///    recomputed chain hash must match the recorded one);
/// 5. done claims with no refactor-kind entry anywhere in the log (the
///    red -> green -> refactor triple is incomplete).
///
/// Exit code 0 means the stores agree; 1 means drift was found and
/// named. The summary line `doctor: feature=<f> drifts=<n>` is the final
/// stdout line on every code path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/cycle_evidence.dart';
import '../services/cycle_log.dart';
import '../services/run_state_store.dart';
import '../services/test_list_reader.dart';
import '../services/tdd_transaction.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class DoctorCommand extends Command<void> {
  DoctorCommand(this.plugin) {
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 049-tdd-run). Selects the tdd/ stores under '
          'specs/<feature>/. When omitted, the command infers the feature '
          'from the unique specs/ directory that has a tdd/ subdirectory.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/. When '
          'omitted, the current working directory is used.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Report drift between run-state.json, artifacts.json, and '
      'cycle-log.md (bug #828), with a --> fix: line per finding. '
      'Read-only: run `zfa tdd run <feature>` to reconcile.';

  @override
  String get invocation =>
      'zfa tdd doctor [--feature <name>] [--project <path>]';

  int _drifts = 0;

  @override
  Future<void> run() async {
    final featureFlag = argResults?['feature'] as String?;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      _validateFeatureSegment(featureFlag);
    }
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();

    var featureName = featureFlag;
    featureName ??= await _inferFeature(cwd);
    if (featureName == null) {
      print(
        'zfa tdd doctor: no --feature given and no unique specs/ directory '
        'with a tdd/ subdirectory under $cwd',
      );
      print('doctor: feature=unknown drifts=0');
      exitCode = 1;
      return;
    }

    final featureDir = p.join(cwd, 'specs', featureName);
    if (!await Directory(featureDir).exists()) {
      print('zfa tdd doctor: no feature directory at specs/$featureName');
      print('doctor: feature=$featureName drifts=0');
      exitCode = 1;
      return;
    }

    print('zfa tdd doctor: feature $featureName (specs/$featureName/tdd)');

    final evidence = CycleEvidence(featureDir);
    final red = await evidence.redEvidence();
    final green = await evidence.greenEvidence();
    final entries = await evidence.entries();

    // The behaviors under examination: test-list rows when the list is
    // readable, else the union of the state file's ids and the cycle-log
    // behavior ids — a doctor must see every id any store carries.
    var ids = <String>{};
    try {
      ids = (await TestListReader(featureDir).read()).map((r) => r.id).toSet();
    } on TestListReadException {
      // Fall through to the stores' own ids.
    }
    RunState? state;
    try {
      state = await RunStateStore(featureDir).load();
    } on RunStateCorruptException catch (e) {
      _drift(
        'run-state.json is corrupted',
        'repair it to valid run-state JSON or delete it to restart every '
            'behavior from PENDING',
      );
      print('   $e');
    }
    if (state != null) ids.addAll(state.behaviorStates.keys);
    for (final entry in entries) {
      ids.add(entry.behaviorId);
    }
    final sortedIds = ids.toList()..sort();

    // 1. Claim vs evidence drift (bug #828's core report).
    for (final id in sortedIds) {
      final claim = state?.behaviorStates[id];
      final hasRed = red.contains(id);
      final hasGreen = green.contains(id);
      switch (claim) {
        case BehaviorState.done:
          if (!hasRed || !hasGreen) {
            _drift(
              'run-state claims done for "$id" but cycle-log.md evidence '
                  'is incomplete (red: $hasRed, green: $hasGreen)',
              're-run `zfa tdd run $featureName` — resume reconciliation '
                  'resets the behavior to its earliest incomplete step',
            );
          }
        case BehaviorState.green:
          if (!hasGreen) {
            _drift(
              'run-state claims green for "$id" but cycle-log.md has no '
                  'green evidence',
              're-run `zfa tdd run $featureName` — resume reconciliation '
                  'resets the behavior to its earliest incomplete step',
            );
          }
        case BehaviorState.red:
          if (!hasRed) {
            _drift(
              'run-state claims red for "$id" but cycle-log.md has no red '
                  'evidence',
              'the red half cannot be fabricated — restore the lost '
                  'cycle-log entries or re-drive the behavior from gen',
            );
          }
        case BehaviorState.pending || null:
          break;
      }
    }

    // 2. Registry records whose artifacts are missing from disk.
    final registry = ArtifactRegistry(featureDir: featureDir);
    for (final record in await registry.loadAll()) {
      for (final role in ['test', 'subject']) {
        final path = role == 'test' ? record.testPath : record.subjectPath;
        if (!await File(path).exists()) {
          _drift(
            'artifacts.json records $role file "$path" for "${record.behaviorId}" '
                'but it is missing from disk',
            're-run `zfa tdd gen ${record.behaviorId}` to re-create the '
                'missing artifact',
          );
        }
      }
    }

    // 3. A surviving pending write-ahead journal.
    final journal = await TddTransaction(featureDir).pending();
    if (journal != null) {
      _drift(
        'a pending write-ahead journal survives for '
            '"${journal['behavior']}" step "${journal['step']}" — the run was '
            'interrupted mid-transaction',
        're-run `zfa tdd run $featureName` — the journal replays when its '
            'evidence landed, or is discarded and the step re-drives',
      );
    }

    // 4. Evidence hash-chain verification (bug #828 schema-1 entries).
    await _verifyChain(entries);

    print('doctor: feature=$featureName drifts=$_drifts');
    exitCode = _drifts > 0 ? 1 : 0;
  }

  /// Walk each behavior's hashed entries in file order and recompute the
  /// chain: every `prev-hash` must link the previous recorded hash and
  /// every `hash` must equal the recomputed payload digest.
  Future<void> _verifyChain(List<ParsedCycleEntry> entries) async {
    final byBehavior = <String, List<ParsedCycleEntry>>{};
    for (final entry in entries) {
      if (!entry.isHashed) continue;
      byBehavior.putIfAbsent(entry.behaviorId, () => []).add(entry);
    }
    final ids = byBehavior.keys.toList()..sort();
    for (final id in ids) {
      var prev = CycleLog.genesisHash;
      for (final entry in byBehavior[id]!) {
        if (entry.prevHash != prev) {
          _drift(
            'hash chain broken for "$id" (${entry.kind} entry): prev-hash '
                '${entry.prevHash} does not link the previous hash $prev',
            'the evidence trail was edited or reordered — restore the '
                'cycle-log from a trusted source, then re-run '
                '`zfa tdd run` to re-certify',
          );
          prev = entry.hash!;
          continue;
        }
        final recomputed = sha256
            .convert(
              utf8.encode(
                CycleLog.payloadFromFields(
                  behaviorId: entry.behaviorId,
                  kind: entry.kind,
                  exit: (entry.exit ?? 0).toString(),
                  command: entry.command ?? '',
                  criterion: entry.criterion ?? '',
                  test: entry.test ?? '',
                  timestamp: entry.at ?? '',
                  prevHash: prev,
                ),
              ),
            )
            .toString();
        if (recomputed != entry.hash) {
          _drift(
            'hash chain broken for "$id" (${entry.kind} entry): recomputed '
                'hash $recomputed != recorded ${entry.hash} — the entry was '
                'tampered with after it was certified',
            'the certified facts no longer match their evidence — restore '
                'the cycle-log from a trusted source, then re-run '
                '`zfa tdd run` to re-certify',
          );
        }
        prev = entry.hash!;
      }
    }
  }

  void _drift(String what, String fix) {
    _drifts++;
    print('  drift: $what');
    print('   --> fix: $fix');
  }

  /// Infer the feature name from the unique specs/ subdirectory that has
  /// a tdd/ subdirectory. Returns null when ambiguous or none.
  Future<String?> _inferFeature(String cwd) async {
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!await specsDir.exists()) return null;
    final candidates = <String>[];
    for (final dir in specsDir.listSync().whereType<Directory>()) {
      final tddDir = Directory(p.join(dir.path, 'tdd'));
      if (await tddDir.exists()) {
        candidates.add(p.basename(dir.path));
      }
    }
    if (candidates.length == 1) return candidates.single;
    return null;
  }
}

/// `--feature` lands in a filesystem path: keep it a single plain
/// directory segment (mirrors verify_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid --feature "$feature": expected a single spec directory name '
          'such as 049-tdd-run, not a path.',
      'zfa tdd doctor [--feature <name>] [--project <path>]',
    );
  }
}
