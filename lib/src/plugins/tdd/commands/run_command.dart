/// `zfa tdd run <feature>` — the resumable driver for the full
/// red-green-refactor loop (spec 049-tdd-run, FR-001..011; 041 Phase 10,
/// T070-T076).
///
/// Given a feature with a behavior test list, the driver walks each
/// behavior through the certified steps delivered by specs 044 (`gen`),
/// 046 (`verify-red`), 047 (`make`), and 048 (`refactor`), spawning each
/// as a sub-process of this CLI and consuming its machine-readable
/// contract (summary line + exit code — never prose). Per-behavior state
/// plus the in-flight behavior/step persist to `tdd/run-state.json` after
/// every completed step, so a run interrupted for minutes or weeks resumes
/// exactly where it stopped.
///
/// Honesty rules:
/// - Evidence beats state: a behavior is DONE only when its red AND green
///   entries exist in `tdd/cycle-log.md`; a state-file claim without
///   evidence is demoted to the evidence-backed state (FR-003).
/// - Any step failure stops the run immediately, non-zero: the behavior is
///   left at its last fully-completed state, the failing step and outcome
///   are named, later behaviors never start, and resume instructions are
///   printed (FR-007). Bounded partial progress is the designed outcome of
///   a stop; silently faking progress is the forbidden one.
/// - A corrupted state file stops the driver naming the corruption and the
///   recovery path; a second concurrent run is refused via the in-flight
///   marker (FR-006).
/// - The driver never edits a test or source file, never retries a failed
///   step silently, and never marks DONE without complete evidence
///   (FR-008).
///
/// Machine contract (FR-009/FR-010): every completed step prints
/// `[run] <behavior> <step> -> <outcome>`, and every invocation ends with
/// the final summary line
/// `run: feature=<f> result=<r> pending=<n> red=<n> green=<n> done=<n>`
/// plus ` stopped_at=<behavior>:<step>` when stopped. Exit codes:
/// 0 complete, 1 stopped, 2 runner-error, 3 corrupt-state,
/// 4 concurrent-run — 0 means exactly "all DONE with complete evidence".
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/cycle_evidence.dart';
import '../services/run_state_store.dart';
import '../services/step_runner.dart';
import '../services/test_list_reader.dart';
import '../tdd_plugin.dart';

class RunCommand extends Command<void> {
  RunCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory '
          'is used. The driver never mutates the process-global working '
          'directory.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Path to the zfa CLI entrypoint used to spawn the step commands '
          '(defaults to this package\'s bin/zfa.dart). Point this at a '
          'scripted fake to drive the loop against stubbed steps.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'run';

  @override
  String get description =>
      'Drive every behavior in a feature\'s tdd/test-list.md through '
      'gen -> verify-red -> make -> refactor, resuming from '
      'tdd/run-state.json and stopping honestly on any step failure '
      '(spec 049).';

  @override
  String get invocation =>
      'zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]';

  static const _exitComplete = 0;
  static const _exitStopped = 1;
  static const _exitRunnerError = 2;
  static const _exitCorruptState = 3;
  static const _exitConcurrentRun = 4;

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      throw UsageException(
        'missing <feature> — name the spec directory whose test list to '
        'drive (e.g. 049-tdd-run)',
        invocation,
      );
    }
    final feature = rest.first;
    _validateFeatureSegment(feature);
    final projectFlag = argResults?['project'] as String?;
    final projectRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final zfaBin = argResults?['zfa-bin'] as String?;

    final featureDir = p.join(projectRoot, 'specs', feature);

    // -----------------------------------------------------------------
    // 1. Feature directory (misfire-stop when absent).
    // -----------------------------------------------------------------
    if (!await Directory(featureDir).exists()) {
      print(
        'zfa tdd run: no feature directory at '
        '${p.relative(featureDir, from: projectRoot)} (project root: '
        '$projectRoot)',
      );
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }

    final store = RunStateStore(featureDir);

    // -----------------------------------------------------------------
    // 2. Load state — corruption stops with the recovery path (FR-006).
    // -----------------------------------------------------------------
    RunState? loaded;
    try {
      loaded = await store.load();
    } on RunStateCorruptException catch (e) {
      print('zfa tdd run: ${e.message}');
      _printSummary(feature, 'corrupt-state', const [], null);
      exitCode = _exitCorruptState;
      return;
    }

    // -----------------------------------------------------------------
    // 3. Concurrent-run refusal via the in-flight marker (FR-006).
    // -----------------------------------------------------------------
    final refusal = store.refusalReason(loaded);
    if (refusal != null) {
      print('zfa tdd run: $refusal');
      _printSummary(feature, 'concurrent-run', const [], null);
      exitCode = _exitConcurrentRun;
      return;
    }

    // -----------------------------------------------------------------
    // 4. Read the test list (misfire-stop on malformed rows, FR-011).
    // -----------------------------------------------------------------
    List<BehaviorRow> rows;
    try {
      rows = await TestListReader(featureDir).read();
    } on TestListReadException catch (e) {
      print('zfa tdd run: ${e.message}');
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }
    if (rows.isEmpty) {
      print(
        'zfa tdd run: test list at specs/$feature/tdd/test-list.md has no '
        'behaviors',
      );
      _printSummary(feature, 'runner-error', const [], null);
      exitCode = _exitRunnerError;
      return;
    }
    final activeIds = rows.map((r) => r.id).toSet();

    // -----------------------------------------------------------------
    // 5. Reconcile state with evidence: evidence beats state (FR-003).
    // -----------------------------------------------------------------
    final evidence = CycleEvidence(featureDir);
    var current = _reconcile(
      loaded ?? RunState.empty(feature),
      rows,
      await evidence.redEvidence(),
      await evidence.greenEvidence(),
    );

    // Persist the reconciled state only when something actually changed
    // (new rows, a demotion, a dropped-marker difference) so an idempotent
    // re-run changes nothing at all.
    final loadedDropped = await store.readDropped();
    final needsInitialSave =
        loaded == null ||
        loaded.toJson() != current.toJson() ||
        !_listEquals(loadedDropped, store.computeDropped(current, activeIds));
    if (needsInitialSave) {
      await store.save(current, activeBehaviorIds: activeIds);
    }

    final skipped = rows
        .where((r) => current.behaviorStates[r.id] == BehaviorState.done)
        .length;
    print('zfa tdd run: feature $feature — ${rows.length} behavior(s)');
    if (skipped > 0) print('   $skipped already done — skipping');

    // -----------------------------------------------------------------
    // 6. Drive the loop (FR-001, FR-004..FR-008).
    // -----------------------------------------------------------------
    final runner = StepRunner(zfaBin: zfaBin);
    for (final row in rows) {
      var state = current.behaviorStates[row.id] ?? BehaviorState.pending;
      if (state == BehaviorState.done) continue;

      final inFlightStep = current.inFlightBehaviorId == row.id
          ? current.inFlightStep
          : null;
      final steps = _stepsFor(state, inFlightStep);
      for (final step in steps) {
        // mark -> save -> spawn -> advance -> save: an interruption loses
        // at most the in-flight step (FR-004).
        current = current.markInFlight(row.id, step, ownerPid: pid);
        await store.save(current, activeBehaviorIds: activeIds);

        // Re-check for a concurrent run that claimed the feature after our
        // in-flight marker was written (closes the simultaneous-start race
        // left by the one-shot check at step 3, FR-006). A foreign live pid
        // in the marker means a second run is now in flight, so stop before
        // spawning any step.
        final liveRefusal = store.refusalReason(await store.load());
        if (liveRefusal != null) {
          print('zfa tdd run: $liveRefusal');
          _printSummary(feature, 'concurrent-run', rows, current);
          exitCode = _exitConcurrentRun;
          return;
        }

        StepResult result;
        try {
          result = await runner.run(
            step: step,
            behaviorId: row.id,
            feature: feature,
            projectRoot: projectRoot,
          );
        } on StateError catch (e) {
          // Entrypoint resolution failed before any spawn: runner-error.
          current = current.advance(row.id, state);
          await store.save(current, activeBehaviorIds: activeIds);
          print(
            'zfa tdd run: step failed — behavior=${row.id} step=$step '
            'outcome=runner-error',
          );
          print('   ${e.message}');
          print('   resume: fix the issue, then re-run `zfa tdd run $feature`');
          _printSummary(
            feature,
            'runner-error',
            rows,
            current,
            stoppedAt: '${row.id}:$step',
          );
          exitCode = _exitRunnerError;
          return;
        }

        print('[run] ${row.id} $step -> ${result.outcome}');

        if (!result.success) {
          // Honest stop (FR-007): leave the behavior at its last completed
          // state, name what failed, never start later behaviors. A
          // runner-error outcome (spawn/tooling failure) is its own class
          // (FR-011).
          final isRunnerError = result.outcome == 'runner-error';
          current = current.advance(row.id, state);
          await store.save(current, activeBehaviorIds: activeIds);
          print(
            'zfa tdd run: step failed — behavior=${row.id} step=$step '
            'outcome=${result.outcome}',
          );
          _printOutputExcerpt(result.output);
          print(
            '   resume: fix the failing step, then re-run '
            '`zfa tdd run $feature`',
          );
          _printSummary(
            feature,
            isRunnerError ? 'runner-error' : 'stopped',
            rows,
            current,
            stoppedAt: '${row.id}:$step',
          );
          exitCode = isRunnerError ? _exitRunnerError : _exitStopped;
          return;
        }

        // Evidence check before advancing: a certified step that did not
        // write its evidence is a misfire (FR-003, FR-011).
        final misfire = await _evidenceMisfire(evidence, step, row.id);
        if (misfire != null) {
          current = current.advance(row.id, state);
          await store.save(current, activeBehaviorIds: activeIds);
          print(
            'zfa tdd run: step failed — behavior=${row.id} step=$step '
            'outcome=runner-error',
          );
          print('   $misfire');
          print(
            '   resume: fix the failing step, then re-run '
            '`zfa tdd run $feature`',
          );
          _printSummary(
            feature,
            'runner-error',
            rows,
            current,
            stoppedAt: '${row.id}:$step',
          );
          exitCode = _exitRunnerError;
          return;
        }

        final next = _maxState(state, _targetStateFor(step));
        current = current.advance(row.id, next);
        await store.save(current, activeBehaviorIds: activeIds);
        state = next;
      }
    }

    // -----------------------------------------------------------------
    // 7. Complete: every behavior DONE with complete evidence (FR-010).
    // -----------------------------------------------------------------
    final allDone = rows.every(
      (r) => current.behaviorStates[r.id] == BehaviorState.done,
    );
    if (!allDone) {
      // Defensive: the loop only exits cleanly when every row reached
      // done; anything else means the driver's own invariant broke.
      print(
        'zfa tdd run: internal error — loop finished with non-DONE '
        'behaviors',
      );
      _printSummary(feature, 'runner-error', rows, current);
      exitCode = _exitRunnerError;
      return;
    }
    _printSummary(feature, 'complete', rows, current);
    exitCode = _exitComplete;
  }

  // -------------------------------------------------------------------
  // Reconciliation (FR-003: evidence beats state).
  // -------------------------------------------------------------------

  /// Merge loaded state with the current test list: new rows enter as
  /// PENDING, removed rows are retained (dropped), and a DONE claim
  /// without both red and green evidence demotes to the highest
  /// evidence-backed state. In-flight markers survive the merge.
  RunState _reconcile(
    RunState state,
    List<BehaviorRow> rows,
    Set<String> red,
    Set<String> green,
  ) {
    final states = Map<String, BehaviorState>.from(state.behaviorStates);
    for (final row in rows) {
      final claimed = states[row.id] ?? BehaviorState.pending;
      var effective = claimed;
      if (claimed == BehaviorState.done) {
        final hasRed = red.contains(row.id);
        final hasGreen = green.contains(row.id);
        if (hasRed && hasGreen) {
          effective = BehaviorState.done;
        } else if (hasGreen) {
          effective = BehaviorState.green;
        } else if (hasRed) {
          effective = BehaviorState.red;
        } else {
          effective = BehaviorState.pending;
        }
      }
      states[row.id] = effective;
    }
    return RunState(
      feature: state.feature,
      behaviorStates: Map.unmodifiable(states),
      inFlightBehaviorId: state.inFlightBehaviorId,
      inFlightStep: state.inFlightStep,
      inFlightOwnerPid: state.inFlightOwnerPid,
    );
  }

  // -------------------------------------------------------------------
  // Step sequencing (FR-001, FR-005).
  // -------------------------------------------------------------------

  /// The steps still to run for a behavior in [state], re-entering at
  /// [inFlightStep] when a crashed run left its marker (U23).
  List<String> _stepsFor(BehaviorState state, String? inFlightStep) {
    const full = ['gen', 'verify-red', 'make', 'refactor'];
    var start = switch (state) {
      BehaviorState.pending => 0,
      BehaviorState.red => 2,
      BehaviorState.green => 3,
      BehaviorState.done => 4,
    };
    if (inFlightStep != null) {
      final index = full.indexOf(inFlightStep);
      if (index >= 0) start = index;
    }
    return full.sublist(start.clamp(0, full.length));
  }

  /// The state a successful [step] certifies for a behavior.
  BehaviorState _targetStateFor(String step) => switch (step) {
    'gen' => BehaviorState.pending,
    'verify-red' => BehaviorState.red,
    'make' => BehaviorState.green,
    'refactor' => BehaviorState.done,
    _ => throw ArgumentError.value(step, 'step', 'unknown TDD step'),
  };

  BehaviorState _maxState(BehaviorState a, BehaviorState b) =>
      a.index >= b.index ? a : b;

  /// Non-null when a certified step failed to write the evidence its
  /// contract promises (FR-003): verify-red must leave a red entry, make a
  /// green entry, and refactor requires both to mark DONE.
  Future<String?> _evidenceMisfire(
    CycleEvidence evidence,
    String step,
    String behaviorId,
  ) async {
    switch (step) {
      case 'verify-red':
        if (!await _hasEvidence(evidence.redEvidence, behaviorId)) {
          return 'verify-red certified but no red evidence entry exists for '
              '"$behaviorId" in tdd/cycle-log.md';
        }
      case 'make':
        if (!await _hasEvidence(evidence.greenEvidence, behaviorId)) {
          return 'make reported green but no green evidence entry exists for '
              '"$behaviorId" in tdd/cycle-log.md';
        }
      case 'refactor':
        final hasRed = await _hasEvidence(evidence.redEvidence, behaviorId);
        final hasGreen = await _hasEvidence(evidence.greenEvidence, behaviorId);
        if (!hasRed || !hasGreen) {
          return 'refactor certified but evidence for "$behaviorId" is '
              'incomplete in tdd/cycle-log.md '
              '(red: $hasRed, green: $hasGreen)';
        }
    }
    return null;
  }

  Future<bool> _hasEvidence(
    Future<Set<String>> Function() evidence,
    String behaviorId,
  ) async {
    return (await evidence()).contains(behaviorId);
  }

  // -------------------------------------------------------------------
  // Reporting (FR-009, FR-010).
  // -------------------------------------------------------------------

  void _printSummary(
    String feature,
    String result,
    List<BehaviorRow> rows,
    RunState? state, {
    String? stoppedAt,
  }) {
    var pending = 0;
    var red = 0;
    var green = 0;
    var done = 0;
    for (final row in rows) {
      switch (state?.behaviorStates[row.id] ?? BehaviorState.pending) {
        case BehaviorState.pending:
          pending++;
        case BehaviorState.red:
          red++;
        case BehaviorState.green:
          green++;
        case BehaviorState.done:
          done++;
      }
    }
    print(
      'run: feature=$feature result=$result pending=$pending red=$red '
      'green=$green done=$done'
      '${stoppedAt != null ? ' stopped_at=$stoppedAt' : ''}',
    );
  }

  void _printOutputExcerpt(String output) {
    final lines = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .take(3);
    for (final line in lines) {
      print('   $line');
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Segment check for the positional feature argument: it lands in a
/// filesystem path, so keep it a single plain directory segment (mirrors
/// verify_red_command.dart).
void _validateFeatureSegment(String feature) {
  if (feature.contains('/') ||
      feature.contains(r'\') ||
      feature == '.' ||
      feature == '..') {
    throw UsageException(
      'invalid feature "$feature": expected a single spec directory name '
          'such as 049-tdd-run, not a path.',
      'zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]',
    );
  }
}
