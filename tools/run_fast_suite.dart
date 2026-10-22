// The fast tier's sanctioned entrypoint (issue #1994).
//
// WHY THIS EXISTS
// ---------------
// The fast tier runs SERIAL by design, and that is a CORRECTNESS
// requirement, not a performance knob: `dart test` runs the suites as
// isolates of ONE process, so `Directory.current` and `dart:io exitCode`
// are process-global. In a parallel lane one suite's chdir window
// silently redirects every concurrent suite's relative-path I/O into its
// temp fixture — the three consecutive red master runs of #1632/#1682
// (service/route/dream verdicts reading a sibling's exit code, relative
// path readers resolving inside a sibling's fixture).
//
// `dart_test.yaml`'s `concurrency: 1` alone does NOT hold that line:
// package:test resolves `concurrency => _concurrency ?? defaultConcurrency`
// (test_core's Configuration), so a CLI `-j 2` overrides the config
// SILENTLY. Issue #1994 is the bill for that: on a shared host under load
// ~390 the fleet-wide `dart test -j 2` produced spawn-ceiling false
// timeouts AND cross-suite CWD contamination (`pubspec.yaml not found`
// mid-setup) — every failing suite green in isolation.
//
// So the cap has to live where the invocation is: this entrypoint owns
// it. It runs the fast tier with an explicit `-j 1` and REFUSES a
// parallel request instead of silently inheriting one.
//
// WHAT IT RUNS
// ------------
// The same lane CI's `dart_core` job runs — `dart test test` minus the
// `flutter` and `e2e` tiers (the slow tier stays excluded by
// dart_test.yaml's default `exclude_tags: slow`). The `e2e` suites drive
// real temp projects (`dart pub get` + `build_runner`); on a loaded host
// they are what pushes the fast tier past a two-hour window (#1994),
// while CI's fast lane measures ~12 minutes.
//
// USAGE
// -----
//   dart run tools/run_fast_suite.dart            # the fast tier, serial
//   dart run tools/run_fast_suite.dart test/core  # a subset, still serial
//
// ENVIRONMENT
// -----------
//   ZFA_TEST_TIMEOUT_SCALE  stretch the helper budgets on a slow host (see
//                           test/README.md). The `spawn` tag's own ceiling
//                           is a fixed factor and is not affected.
//
// EXIT CODE
// ---------
//   0  the fast tier passed
//   2  a parallel run was refused (see the message)
//   *  the fast tier's own exit code
//
// The cap lives here (not in a shell wrapper) so the fast tier's own
// tier-integrity pin can unit-test the refusal WITHOUT spawning a
// process: a fast-lane suite that spawns a child is a heavyweight suite
// under the B5 census (test/tier_integrity_test.dart).
import 'dart:io';

/// The concurrency the fast tier runs at. `dart test`'s default is the
/// core count; this repo's suite needs ONE (see the header).
const int fastSuiteConcurrency = 1;

/// The tag selector CI's `dart_core` lane runs: the `flutter` tier is
/// covered by the `test` (flutter) job and the `e2e` tier drives real
/// temp projects (#1510) — both stay off the fast lane.
const String fastSuiteExcludeTags = 'flutter || e2e';

/// The message a refused parallel run prints. Names the knob, the reason
/// (the process-global CWD/exitCode invariant) and the issue.
String concurrencyRefusal(int requested) =>
    '''
run_fast_suite: REFUSING concurrency=$requested.

This repo's fast tier runs SERIAL by design (#1682): `dart test` runs the
suites as isolates of ONE process, so Directory.current and dart:io
exitCode are process-global. In a parallel lane one suite's chdir window
silently redirects every concurrent suite's relative-path I/O into its
temp fixture (#1632's three red master runs).

dart_test.yaml pins `concurrency: 1`, but a CLI -j overrides that pin
silently (package/test: concurrency => _concurrency ?? defaultConcurrency)
— that silent override is what issue #1994 reports: on a loaded shared host
the fast suite flaked (spawn ceilings, `pubspec.yaml not found` mid-setup)
while every failing suite passed in isolation.

Run the fast tier through this entrypoint (it pins -j 1), or run a single
suite directly:
  dart test test/core/result_test.dart
''';

/// The concurrency requested on the command line, or null when the
/// invocation does not ask for one (package:test then uses
/// dart_test.yaml's `concurrency: 1`).
///
/// Accepts every spelling package:test accepts: `-j N`, `-jN`,
/// `--concurrency N` and `--concurrency=N`. The RAW text is returned so
/// an unparsable value is reported instead of silently ignored.
String? requestedConcurrencyArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-j' || arg == '--concurrency') {
      return i + 1 < args.length ? args[i + 1] : null;
    }
    if (arg.startsWith('-j') && arg.length > 2) {
      return arg.substring(2);
    }
    if (arg.startsWith('--concurrency=')) {
      return arg.substring('--concurrency='.length);
    }
  }
  return null;
}

/// The `dart test` invocation for the fast tier: [args] (paths and flags)
/// plus the CI lane's tag selector and the explicit serial flag.
///
/// The serial flag is EXPLICIT on purpose: an implicit default is exactly
/// what a fleet-wide `-j 2` overrides. It comes LAST so the cap wins over
/// any `-j` the caller passed (package:test keeps the last value).
List<String> fastSuiteCommand(List<String> args) => [
  ...args,
  '--exclude-tags',
  fastSuiteExcludeTags,
  '-j',
  '$fastSuiteConcurrency',
];

/// The entrypoint's decision for [args]: either the `dart test`
/// invocation to run, or a refusal (the message to print and the exit
/// code to return).
///
/// The decision is a pure function so the fast tier's own tier-integrity
/// pin can assert the refusal — the same code path `main` takes — without
/// spawning a process.
class FastSuiteDecision {
  const FastSuiteDecision.run(this.command) : refusal = null, exitCode = 0;

  const FastSuiteDecision.refuse(this.refusal) : command = null, exitCode = 2;

  /// The `dart test` arguments to run, or null when the run is refused.
  final List<String>? command;

  /// The refusal message, or null when the run proceeds.
  final String? refusal;

  /// The exit code the entrypoint returns.
  final int exitCode;
}

/// Decides what the entrypoint does with [args].
FastSuiteDecision decideFastSuite(List<String> args) {
  final raw = requestedConcurrencyArg(args);
  if (raw != null) {
    final requested = int.tryParse(raw);
    if (requested == null) {
      return FastSuiteDecision.refuse(
        'run_fast_suite: bad concurrency value "$raw" (expected an '
        'integer >= 1).\n',
      );
    }
    if (requested < 1) {
      return FastSuiteDecision.refuse(
        'run_fast_suite: bad concurrency value $requested (expected >= 1).\n',
      );
    }
    if (requested > fastSuiteConcurrency) {
      return FastSuiteDecision.refuse(concurrencyRefusal(requested));
    }
  }
  return FastSuiteDecision.run(
    fastSuiteCommand(args.isEmpty ? ['test'] : args),
  );
}

Future<void> main(List<String> args) async {
  final decision = decideFastSuite(args);
  if (decision.refusal != null) {
    stderr.write(decision.refusal!);
    exitCode = decision.exitCode;
    return;
  }

  final process = await Process.start('dart', [
    'test',
    ...decision.command!,
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await process.exitCode;
}
