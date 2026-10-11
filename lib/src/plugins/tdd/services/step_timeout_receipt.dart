/// `StepTimeoutReceipt` — the durable record of a make step killed at the
/// run driver's deadline (spec 1529, US1 / issue #1529 failure 1).
///
/// The #742 kill contract grades a timed-out step `runner-error` — never
/// a silent pass — but the kill was DIAGNOSE-BLIND: no receipt, and a
/// captured output tail that is usually just the step header because the
/// child sits inside a silent `flutter test` invocation. The operator
/// could only blind re-roll.
///
/// This receipt turns the kill into an informed decision:
///
/// - WHERE: `specs/<feature>/tdd/make.<behaviorId>.timeout.json` (the
///   stable name the issue's `make.u8.*.json` glob matches; the latest
///   kill wins — the receipt is evidence for the CURRENT misfire);
/// - WHAT: the child's full argv as executed, the ACTUAL elapsed wall
///   time, the configured deadline, and the captured output tail;
/// - WHICH PHASE: `compiling` | `running` | `unknown` with the evidence
///   used (the descendant process-tree snapshot when the platform could
///   observe it, then captured-output markers, then an honest unknown).
///
/// The receipt is ADDITIVE evidence, never a gate: the writer is
/// best-effort and a failed write is reported, not fatal. Nothing in
/// this spec reads the receipt to make decisions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tdd_timeout.dart';

/// The receipt's schema token (versioned like every other TDD artifact).
const String kMakeTimeoutReceiptSchema = 'tdd-make-timeout-receipt.v1';

/// The structured timeout diagnostics a [StepResult] carries when its
/// step child was killed at the deadline (spec 1529, U7). The run driver
/// writes the durable receipt from this data — the step runner does not
/// know the feature directory.
class StepTimeoutInfo {
  final String behaviorId;
  final String step;

  /// The child's argv as executed (entrypoint + step argv + flags).
  final List<String> argv;

  /// The child's actual wall-clock lifetime until the kill.
  final Duration elapsed;

  /// The configured deadline that fired.
  final Duration deadline;

  /// The phase inference (evidence-carrying).
  final PhaseVerdict phase;

  /// The captured output tail (what the child produced before the kill).
  final String outputTail;

  /// The working directory the child ran in, when known.
  final String? workingDirectory;

  const StepTimeoutInfo({
    required this.behaviorId,
    required this.step,
    required this.argv,
    required this.elapsed,
    required this.deadline,
    required this.phase,
    required this.outputTail,
    this.workingDirectory,
  });

  /// The durable receipt this info produces (same data, receipt shape).
  StepTimeoutReceipt toReceipt({required String capturedAt}) =>
      StepTimeoutReceipt(
        behaviorId: behaviorId,
        step: step,
        argv: argv,
        workingDirectory: workingDirectory,
        elapsed: elapsed,
        deadline: deadline,
        phase: phase,
        outputTail: outputTail,
        capturedAt: capturedAt,
      );
}

/// The durable kill record (see the library doc).
class StepTimeoutReceipt {
  final String behaviorId;
  final String step;
  final List<String> argv;
  final String? workingDirectory;
  final Duration elapsed;
  final Duration deadline;
  final PhaseVerdict phase;
  final String outputTail;
  final String capturedAt;

  const StepTimeoutReceipt({
    required this.behaviorId,
    required this.step,
    required this.argv,
    required this.elapsed,
    required this.deadline,
    required this.phase,
    required this.outputTail,
    required this.capturedAt,
    this.workingDirectory,
  });

  /// The stable receipt file name: `make.<behaviorId>.timeout.json` —
  /// the issue's operator globs `make.u8.*.json`; the latest kill wins.
  static String fileNameFor(String behaviorId) =>
      'make.$behaviorId.timeout.json';

  Map<String, dynamic> toJson() => {
    'schema': kMakeTimeoutReceiptSchema,
    'behavior': behaviorId,
    'step': step,
    'argv': argv,
    if (workingDirectory != null) 'working_directory': workingDirectory,
    'elapsed_ms': elapsed.inMilliseconds,
    'deadline_ms': deadline.inMilliseconds,
    'phase': phase.phase,
    'phase_evidence': phase.evidence,
    'output_tail': outputTail,
    'captured_at': capturedAt,
  };
}

/// Writes [receipt] to `<featureDir>/tdd/[fileNameFor]` and returns the
/// written path. The feature tdd dir is created when absent (the receipt
/// must land even on a first-misfire run).
Future<String> writeStepTimeoutReceipt({
  required String featureDir,
  required StepTimeoutReceipt receipt,
}) async {
  final file = File(
    p.join(
      featureDir,
      'tdd',
      StepTimeoutReceipt.fileNameFor(receipt.behaviorId),
    ),
  );
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(receipt.toJson()));
  return file.path;
}

/// The best-effort write outcome (spec 1529 FR-12): the receipt is never
/// a gate, so a failed write surfaces as a REPORTED error — the caller
/// prints it and the run's outcome never changes.
class StepTimeoutReceiptWriteOutcome {
  final bool written;
  final String? path;
  final String? error;

  const StepTimeoutReceiptWriteOutcome({
    required this.written,
    this.path,
    this.error,
  });
}

/// [writeStepTimeoutReceipt]'s never-throws wrapper: every failure mode
/// (unwritable directory, disk full) degrades to `written: false` with
/// the error text for the failure report.
Future<StepTimeoutReceiptWriteOutcome> writeStepTimeoutReceiptReported({
  required String featureDir,
  required StepTimeoutReceipt receipt,
}) async {
  try {
    final path = await writeStepTimeoutReceipt(
      featureDir: featureDir,
      receipt: receipt,
    );
    return StepTimeoutReceiptWriteOutcome(written: true, path: path);
  } on Exception catch (e) {
    return StepTimeoutReceiptWriteOutcome(written: false, error: e.toString());
  }
}
