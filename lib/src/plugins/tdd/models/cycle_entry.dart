/// `CycleLogEntry` entity — one row of `tdd/cycle-log.md`.
///
/// Extended by spec 046-tdd-verify-red (T002): red entries carry the full
/// 8-field evidence contract — behavior id, source criterion, test path,
/// runner command, runner exit code, classification, captured failure
/// output, and timestamp (spec 046 FR-006).
///
/// Extended by spec 048-tdd-refactor (T003): the `refactor` kind records
/// refactor evidence entries. The classification assert is relaxed to
/// `kind != red || classification != null` so refactor (and green) entries
/// may omit the failure classification; only red entries carry one. The
/// `refactorActions` list renders as the `actions:` block per
/// contracts/refactor.md, and `isNoOp` flags a clean no-op entry.
///
/// Extended by issue #1329: the `error` kind records a FAILED STEP's
/// diagnostic evidence (the spawned command, the exit code, and the
/// truncated stderr/stdout tail — the same evidence shape the red/green
/// cycles record) appended by the run driver's error-outcome path. The
/// kind is deliberately NOT `red`: red is CERTIFIED red evidence the
/// reconciliation and the make skip transition key on, and an error entry
/// must never satisfy it — the retry after a transient failure re-drives
/// the failed step honestly. The optional `outcome` field names the
/// step's own failure token (`error`, `crashed`, `runner-error`, ...);
/// it renders as the `- outcome:` line only when set, outside the
/// chain-hash payload (the `- evidence:` / `- subject-hash:` additive
/// precedents), so the evidence schema stays v1.
///
/// Existing red/green rendering stays byte-compatible (U10 invariant).
library;

import 'generation_plan.dart';
import 'refactor_action.dart';

enum CycleEntryKind { red, green, refactor, error, refresh }

enum FailureClass {
  assertionFailure,
  compileError,
  loadError,
  unexpectedGreen,
  skipped,
  runnerError,
}

/// Issue #1653: the single duration formatter for the refactor receipt's
/// per-phase and per-pass timing evidence (and the init pre-resolve's ✓
/// line, which shares the vocabulary). `< 60s` renders one-decimal seconds
/// (`12.3s`); a minute or more renders `XmYYs` (`1m05s`); sub-second
/// durations still show one decimal (`0.0s`) so a zero-measurement reads
/// as a measurement, not a gap.
String formatPhaseDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (duration.inMinutes > 0) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m${seconds.toString().padLeft(2, '0')}s';
  }
  return '${(ms / 1000).toStringAsFixed(1)}s';
}

class CycleLogEntry {
  final String behaviorId;
  final CycleEntryKind kind;
  final String runnerCommand;
  final int exitCode;
  final String capturedOutput;
  final FailureClass? classification;

  /// The failing authored assertion's identity for red entries (issue
  /// #959): extracted from the runner transcript by `failingAssertionOf`.
  /// Nullable — present only when the transcript names the assertion;
  /// rendered as the optional `- evidence:` field line. Outside the
  /// chain-hash payload (which covers the certified facts only), so the
  /// evidence schema stays at v1.
  final String? redEvidence;

  /// The sha256 of the subject file at certification time (issue #1036):
  /// red entries record the subject shape the certified red exercised,
  /// green entries the shape the certified green exercised. The make
  /// skip transition compares the CURRENT subject hash against these to
  /// refuse a skip on a subject the certified evidence never exercised
  /// (the born-green placeholder class). Nullable — legacy entries and
  /// runs with no subject artifact omit the field. Rendered as the
  /// optional `- subject-hash:` field line, outside the chain-hash
  /// payload, so the evidence schema stays at v1 (the `- evidence:`
  /// precedent).
  final String? subjectHash;

  /// The spec criterion the behavior traces to (e.g. `FR-006`).
  final String sourceCriterion;

  /// The step's own failure outcome token for `error` entries (issue
  /// #1329): `error` (a spawned step exited non-zero), `crashed`,
  /// `runner-error`, ... — the token the driver printed. Nullable; only
  /// the error-outcome recording sets it. Rendered as the optional
  /// `- outcome:` field line, outside the chain-hash payload, so the
  /// evidence schema stays at v1 (the `- evidence:` precedent).
  final String? outcome;

  /// The registry-recorded path of the test that produced this entry.
  /// For refactor entries this is the suite scope the command re-proved
  /// green (e.g. `test/plugins/tdd/`).
  final String testPath;

  /// ISO-8601 UTC timestamp of the run.
  final String timestamp;

  /// Refactor actions recorded during this cycle (refactor entries only).
  /// Empty for red/green entries; for refactor entries it lists every
  /// applied pass with its command and filesChanged.
  final List<RefactorAction> refactorActions;

  /// True for a refactor entry that recorded zero actions (a clean no-op).
  /// When true the entry is rendered with a `- no-op: true` marker so the
  /// evidence is explicit about the absence of changes (spec 048 FR-008).
  final bool isNoOp;

  /// Recorded generation steps (green/make entries only). Rendered as the
  /// `generation:` block listing each step's command, exit code, and purpose
  /// in execution order (spec 047 FR-006 / FR-008).
  final List<GenerationStep> generationSteps;

  /// Suite baseline failure count captured before generation (green
  /// entries). With a run-cached baseline (issue #741) this is the
  /// cached snapshot's count; 0 when no suite ran (the issue #694
  /// already-green skip transition runs no suite per issue #741).
  final int suiteBaselineFailures;

  /// Suite guard failure count from the pre-run baseline snapshot.
  /// With a run-cached baseline (issue #741) this is the scoped
  /// single-test result's count; 0 when no suite ran (skip transition).
  final int suiteGuardFailures;

  /// New failures introduced by the generation, if any (green entries).
  final List<String> suiteNewFailures;

  /// Issue #1653: per-phase wall durations for refactor entries —
  /// `preflight` (the absolute-green suite run), `registry` (the fixed
  /// pass batch), `re-proof` (the post-pass suite run(s), #1333 retries
  /// included). Rendered as the additive optional `- phases:` line AFTER
  /// the certified facts, OUTSIDE the chain-hash payload (the `- outcome:`
  /// / `- subject-hash:` precedents) — the evidence schema stays v1 and
  /// legacy entries stay parseable. "Without heartbeats the 8m32s would be
  /// indistinguishable from a stuck step" — this is the heartbeat.
  final Map<String, Duration>? phaseDurations;

  CycleLogEntry({
    required this.behaviorId,
    required this.kind,
    required this.runnerCommand,
    required this.exitCode,
    required this.capturedOutput,
    required this.sourceCriterion,
    required this.testPath,
    required this.timestamp,
    this.classification,
    this.outcome,
    this.redEvidence,
    this.subjectHash,
    this.refactorActions = const [],
    this.isNoOp = false,
    this.generationSteps = const [],
    this.suiteBaselineFailures = 0,
    this.suiteGuardFailures = 0,
    this.suiteNewFailures = const [],
    this.phaseDurations,
  }) : assert(
         kind != CycleEntryKind.red || classification != null,
         'Red entries must carry a failure classification.',
       );

  String toMarkdown() {
    final kindLabel = _kindLabel(kind);
    final buf = StringBuffer()
      ..writeln('## Cycle: $behaviorId ($kindLabel)')
      ..writeln()
      ..writeln('- behavior: $behaviorId')
      ..writeln('- kind: $kindLabel');
    if (classification != null) {
      buf.writeln('- classification: ${classification!.name}');
    }
    if (redEvidence != null) {
      buf.writeln('- evidence: $redEvidence');
    }
    if (subjectHash != null) {
      buf.writeln('- subject-hash: $subjectHash');
    }
    if (outcome != null) {
      buf.writeln('- outcome: $outcome');
    }
    buf
      ..writeln('- criterion: $sourceCriterion')
      ..writeln('- test: $testPath')
      ..writeln('- command: `$runnerCommand`')
      ..writeln('- exit: $exitCode')
      ..writeln('- at: $timestamp');
    if (isNoOp) {
      buf.writeln('- no-op: true');
    }
    // Issue #1653: the additive per-phase timing evidence. Rendered only
    // for refactor entries and only when the command handed the durations
    // in — every legacy entry (and every non-refactor kind) renders
    // byte-identically to before.
    if (kind == CycleEntryKind.refactor &&
        phaseDurations != null &&
        phaseDurations!.isNotEmpty) {
      final rendered = phaseDurations!.entries
          .map((e) => '${e.key}=${formatPhaseDuration(e.value)}')
          .join(' ');
      buf.writeln('- phases: $rendered');
    }
    buf
      ..writeln('- output:')
      ..writeln('```')
      ..writeln(capturedOutput.trim())
      ..writeln('```');
    if (kind == CycleEntryKind.refactor && refactorActions.isNotEmpty) {
      buf.writeln('actions:');
      for (final action in refactorActions) {
        buf
          ..writeln('- action: ${action.name}')
          ..writeln('  command: `${action.command}`')
          ..writeln('  exit: ${action.exitCode}');
        if (action.filesChanged.isEmpty) {
          buf.writeln('  changed: (none)');
        } else {
          buf.writeln('  changed: ${action.filesChanged.join(', ')}');
        }
        // Issue #1653: the per-pass heartbeat — how long THIS pass ran.
        // Additive, only when the registry measured it (a scheduling-
        // skipped pass ran no process and records no duration).
        if (action.duration != null) {
          buf.writeln('  duration: ${formatPhaseDuration(action.duration!)}');
        }
        // Issue #1624: a scheduling-skipped pass is auditable as such —
        // the process never spawned, so the evidence says so explicitly
        // (the same additive-note precedent #1587's skipped build step
        // uses). The gate's full note stays in the action record.
        if (action.skipped) {
          buf.writeln(
            '  note: skipped — the pass had no build-relevant input '
            '(issue #1624)',
          );
        }
      }
    }

    if (kind == CycleEntryKind.green) {
      buf.writeln('- generation:');
      if (generationSteps.isEmpty) {
        buf.writeln('  (none)');
      } else {
        for (final step in generationSteps) {
          buf.writeln('  - step: ${step.command}');
          buf.writeln('    exit: ${step.exitCode}');
          buf.writeln('    purpose: ${step.purpose}');
          // Issue #1587: a scheduling-skipped build step is auditable
          // as such — the subprocess never spawned, so the evidence
          // says so explicitly (the additive optional-line precedent).
          if (step.buildSkipped) {
            buf.writeln(
              '    note: skipped — no builder-consumable input changed '
              '(issue #1587)',
            );
          }
        }
      }
      final newFailures = suiteNewFailures.isEmpty
          ? '(none)'
          : suiteNewFailures.join(', ');
      buf.writeln(
        '- suite: baseline=$suiteBaselineFailures '
        'guard=$suiteGuardFailures new=$newFailures',
      );
    }

    buf.writeln();
    return buf.toString();
  }

  /// Map a [CycleEntryKind] to its lowercase contract label.
  ///
  /// Kept as a helper so the red/green/refactor labels stay in one place;
  /// the previous `kind == red ? 'red' : 'green'` ternary silently
  /// mislabelled refactor entries as green (spec 048 Decision 5).
  static String _kindLabel(CycleEntryKind kind) {
    switch (kind) {
      case CycleEntryKind.red:
        return 'red';
      case CycleEntryKind.green:
        return 'green';
      case CycleEntryKind.refactor:
        return 'refactor';
      case CycleEntryKind.error:
        return 'error';
      case CycleEntryKind.refresh:
        return 'refresh';
    }
  }

  @override
  String toString() =>
      'CycleLogEntry($behaviorId, $kind, exit=$exitCode, '
      'class=$classification, steps=${generationSteps.length})';
}
