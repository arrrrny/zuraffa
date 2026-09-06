/// `LadderJournal` — advances the per-behavior contract ladder
/// (`PENDING → RED → MOCKED → REAL → DONE`, issue #1193 / #908) in the
/// unified journal after the realize gates pass, and retires the
/// simulation-mode binding.
///
/// What "the unified journal" means on this codebase today (the #1113
/// structured journal is a separate, still-open issue):
/// - `tdd/run-state.json` — the per-behavior ladder states the run
///   driver, doctor and status read (`RunStateStore`);
/// - `tdd/cycle-log.md` — the unified evidence journal the two-cycle
///   driver appends its `## Two-cycle run:` entries to; the
///   realization entry follows the same no-`- behavior:`-field
///   convention so per-behavior evidence parsers read past it.
///
/// The advance is honest by construction:
/// - only behaviors named by the caller (the realized entities'
///   behaviors) advance — realize never lies about tiers it did not
///   swap;
/// - a behavior at `pending` / `red` / `blocked` never advances (no
///   tier to realize);
/// - the intermediate `REAL` state is persisted BEFORE the terminal
///   `DONE` write, so a crash between the two leaves the tree saying
///   exactly what landed (the swap is real, the terminal advance
///   incomplete — a re-run completes it);
/// - the simulation binding (`tdd/fixtures/manifest.json`, the
///   complete(mocked) marker the provenance reader derives) is retired
///   with its digest recorded; the fixture JSON files themselves stay
///   as differential evidence.
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../models/behavior.dart';
import '../models/run_state.dart';
import 'run_state_store.dart';

/// One behavior's ladder walk, as recorded in the receipt and journal.
class LadderTransition {
  const LadderTransition({required this.behavior, required this.ladder});

  /// The behavior id.
  final String behavior;

  /// The tier chain the advance walked, e.g.
  /// `['MOCKED', 'REAL', 'DONE']`.
  final List<String> ladder;

  Map<String, dynamic> toJson() => {
    'behavior': behavior,
    'ladder': List<String>.of(ladder),
  };
}

/// The outcome of the ladder advance.
class LadderAdvance {
  const LadderAdvance({
    required this.transitions,
    required this.manifestRetired,
    this.manifestDigest,
  });

  /// The per-behavior ladder walks that landed.
  final List<LadderTransition> transitions;

  /// Whether the simulation binding (fixtures manifest) was retired.
  final bool manifestRetired;

  /// sha256 of the retired manifest's bytes, when retired.
  final String? manifestDigest;

  /// The ladder map for the receipt (`{behavior: [tiers...]}`).
  Map<String, List<String>> get ladderMap => {
    for (final transition in transitions)
      transition.behavior: List<String>.of(transition.ladder),
  };
}

class LadderJournal {
  LadderJournal({required this.featureDir, required this.projectRoot});

  /// The feature directory (`specs/<feature>`).
  final String featureDir;

  /// The target project root.
  final String projectRoot;

  String get _feature => p.basename(featureDir);

  String get _manifestPath =>
      p.join(featureDir, 'tdd', 'fixtures', 'manifest.json');

  /// Advance [behaviorIds] through `MOCKED → REAL → DONE` in
  /// `tdd/run-state.json`, then retire the simulation binding.
  ///
  /// The tier each behavior starts from is read from the current state:
  /// `mocked` walks the full ladder, `green` and `real` complete to
  /// `done`, and `pending` / `red` / `blocked` / `done` are left alone
  /// (nothing to realize). A missing run-state file starts empty — only
  /// the advanced behaviors are recorded.
  Future<LadderAdvance> advanceToRealThenDone({
    required Set<String> behaviorIds,
    Map<String, dynamic> evidence = const <String, dynamic>{},
  }) async {
    final store = RunStateStore(featureDir);
    final state = await store.load() ?? RunState.empty(_feature);

    final transitions = <LadderTransition>[];
    final ids = behaviorIds.toList()..sort();
    var intermediate = state;
    var terminal = state;
    for (final id in ids) {
      // An absent state row means the mock-era machinery never recorded
      // the behavior — the caller's scope (the realized entity's
      // behaviors) is authoritative, so the walk starts at MOCKED (the
      // tier the command's own gates just verified). A PRESENT pending /
      // red / blocked row is an honest stop: realize never advances a
      // behavior that is not at a green-tier claim.
      final recorded = state.behaviorStates.containsKey(id);
      final current = state.behaviorStates[id] ?? BehaviorState.mocked;
      switch (current) {
        case BehaviorState.pending:
        case BehaviorState.red:
        case BehaviorState.blocked:
          if (recorded) continue;
          break;
        case BehaviorState.done:
          continue; // already terminal — the idempotent no-op
        case BehaviorState.mocked:
        case BehaviorState.green:
        case BehaviorState.real:
          break;
      }
      final chain = <String>[current.name.toUpperCase()];
      if (current == BehaviorState.mocked) {
        // The REAL tier crossing: only the MOCKED tier crosses it (a
        // green behavior was never mock-bound; it completes to DONE).
        chain.add('REAL');
        intermediate = intermediate.advance(id, BehaviorState.real);
      }
      chain.add('DONE');
      terminal = terminal.advance(id, BehaviorState.done);
      transitions.add(LadderTransition(behavior: id, ladder: chain));
    }

    if (transitions.isNotEmpty) {
      // Crash-safe ordering: the REAL tier lands first, the terminal
      // DONE write second — a crash between leaves an honest REAL.
      await store.save(intermediate);
      await store.save(terminal);
    }

    // Retire the simulation-mode binding: the manifest is the
    // complete(mocked) marker the provenance reader derives; its bytes
    // are digested into the advance (the receipt records them), the
    // fixture JSONs stay as differential evidence.
    var retired = false;
    String? digest;
    final manifest = File(_manifestPath);
    if (await manifest.exists()) {
      final bytes = await manifest.readAsBytes();
      digest = crypto.sha256.convert(bytes).toString();
      await manifest.delete();
      retired = true;
    }

    return LadderAdvance(
      transitions: transitions,
      manifestRetired: retired,
      manifestDigest: digest,
    );
  }

  /// Append the unified realization entry to `tdd/cycle-log.md` — the
  /// same shape the two-cycle driver's `## Two-cycle run:` entries use:
  /// a `## `-delimited section WITHOUT a `- behavior:` field, so the
  /// per-behavior evidence parsers read past it.
  Future<void> appendRealizationEntry({
    required String feature,
    required String adapter,
    required List<String> entities,
    required String contract,
    required String differential,
    required String receipt,
    required String ladder,
  }) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsString('# Cycle Log\n\n');
    }
    await file.writeAsString('''
## Realization: $feature

- feature: $feature
- adapter: $adapter
- entities: ${entities.join(', ')}
- contract: $contract
- differential: $differential
- receipt: $receipt
- ladder: $ladder
- at: ${DateTime.now().toUtc().toIso8601String()}

''', mode: FileMode.append);
  }
}
