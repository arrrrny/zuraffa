/// `TddProfilePreflight` — the issue-#1528 entry baseline: `zfa tdd run` /
/// `zfa tdd gen` ensure the TDD profile exists BEFORE the first step /
/// flow, because a missing `.specify/memory/tdd-profile.md` is a SETUP
/// condition — deterministically detectable, deterministically fixable
/// (the idempotent `tdd init`), and never a reason to drive a loop that
/// stops at its first `verify-red` with the engine-defect-sounding
/// `classification=unresolved`.
///
/// Semantics:
///   * profile present → silent no-op ([ProfilePreflightReport.profilePresent]
///     is true, nothing printed, nothing written — byte-identical to the
///     pre-#1528 behavior, FR-008);
///   * profile missing → the shared idempotent [TddBaselineInit] sequence
///     runs (non-force, non-skin) and every created artifact is logged;
///   * the init sequence misfires → [TddProfilePreflightError] — the
///     caller fail-closes with the `setup-error` verdict BEFORE any
///     behavior is driven (spec 1528 US3).
///
/// `verify-red` deliberately does NOT call this: its FR-008 contract makes
/// it read-only over `test/` and `lib/` (the init writers touch both
/// trees), so verify-red only probes and fail-closes with `setup-error`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline_init.dart';

/// Issue #1528: the machine-readable label for setup conditions (a
/// missing/broken TDD baseline) — `exit_class` in the verdict envelopes,
/// `classification=` in verify-red's summary line, `result=` in the run
/// driver's summary line. Never `unresolved` (the "runner could not
/// classify" verdict a setup condition must never wear).
const String kSetupErrorLabel = 'setup-error';

/// What the entry preflight did.
class ProfilePreflightReport {
  /// The profile already existed: nothing was written, nothing printed.
  final bool profilePresent;

  /// Artifacts the idempotent init sequence created (empty when
  /// [profilePresent]).
  final List<String> created;

  const ProfilePreflightReport({
    required this.profilePresent,
    required this.created,
  });
}

/// The setup failure a caller fail-closes on: the baseline could not be
/// ensured (a writer misfired or the pubspec is unreadable), so the entry
/// must not drive any behavior.
class TddProfilePreflightError implements Exception {
  TddProfilePreflightError(this.message, {this.failures = const []});

  final String message;

  /// The writer failures behind the misfire (journal violations).
  final List<String> failures;

  @override
  String toString() => message;
}

class TddProfilePreflight {
  const TddProfilePreflight();

  /// The probed path — the runner's own constant is the single path truth.
  static const String profilePath = '.specify/memory/tdd-profile.md';

  Future<ProfilePreflightReport> ensure({
    required String projectRoot,
    String commandLabel = 'zfa tdd run',
    void Function(String line)? onLine,
  }) async {
    final profileFile = File(p.join(projectRoot, profilePath));
    if (await profileFile.exists()) {
      return const ProfilePreflightReport(profilePresent: true, created: []);
    }

    void log(String line) => onLine?.call(line);
    log(
      '$commandLabel: preflight — TDD profile missing '
      '($profilePath); running idempotent `zfa tdd init` (issue #1528)',
    );
    final BaselineInitReport report;
    try {
      report = await const TddBaselineInit().ensure(
        projectRoot: projectRoot,
        onLine: log,
        onError: log,
      );
    } on BaselineInitMisfire catch (e) {
      throw TddProfilePreflightError(e.message, failures: e.failures);
    } on StateError catch (e) {
      throw TddProfilePreflightError(
        e.message,
        failures: <String>['baseline_init: ${e.message}'],
      );
    } on FormatException catch (e) {
      throw TddProfilePreflightError(
        'zfa tdd init: misfire — ${e.message}',
        failures: ['baseline_init: ${e.message}'],
      );
    }
    log(
      '$commandLabel: preflight — TDD baseline ensured '
      '${report.created.isEmpty ? '(no new artifacts needed)' : '(created: ${report.created.join(', ')})'}',
    );
    return ProfilePreflightReport(
      profilePresent: false,
      created: report.created,
    );
  }
}
