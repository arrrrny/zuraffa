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
//   2  a parallel run was refused (see the message), a bad concurrency
//      value was given, or a preset was named (a preset's own selector
//      configuration wins over the CLI's, so it would take the run out of
//      the bounded fast lane)
//   *  the fast tier's own exit code
//
// The child is the SDK running this script (Platform.resolvedExecutable),
// not a `dart` resolved through PATH — the entrypoint must work on a
// host whose PATH has no `dart`.
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
///
/// A flag with NO value (a trailing `-j`) returns the empty string — a
/// bad value, not "no concurrency requested". Reporting "not requested"
/// would let the next token be swallowed as the option's value, so
/// `--exclude-tags` would become the value of `-j` and the tag selector
/// would fall through as a positional path.
String? requestedConcurrencyArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '-j' || arg == '--concurrency') {
      if (i + 1 >= args.length) return '';
      // The next token must be the VALUE: a token that is itself a flag
      // (`--exclude-tags`) means the option has no value at all, and
      // swallowing the flag would take the tag selector as the value.
      if (args[i + 1].startsWith('--')) return '';
      return args[i + 1];
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

/// The preset requested on the command line, or null when the invocation
/// does not name one.
///
/// Accepts every spelling package:test accepts: `--preset=<name>`,
/// `--preset <name>`, `-P <name>` and `-P<name>`.
String? requestedPresetArg(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--preset=')) {
      return arg.substring('--preset='.length);
    }
    if (arg == '--preset' || arg == '-P') {
      if (i + 1 >= args.length) return '';
      return args[i + 1];
    }
    if (arg.startsWith('-P') && arg.length > 2) {
      return arg.substring(2);
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

/// The `dart test` argv the entrypoint executes: the `test` subcommand
/// plus [command].
///
/// Lifted out of `main` so the fast tier's own tier-integrity pin can
/// assert the SPAWNED argv without spawning a process — the pin has to
/// see the exact flags the child receives, not just the decision that
/// produced them.
List<String> fastSuiteArgv(List<String> command) => ['test', ...command];

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
        raw.isEmpty
            ? 'run_fast_suite: the concurrency flag has no value (expected '
                'an integer >= 1).\n'
            : 'run_fast_suite: bad concurrency value "$raw" (expected an '
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

  // A preset carries its OWN selector configuration, and that configuration
  // WINS over the CLI's tag selectors (verified against package/test:
  // `--preset=<p> --tags <t>` runs <p>'s include_tags, not <t>'s). Every
  // preset in dart_test.yaml lifts the default `exclude_tags: slow` and
  // most pin an `include_tags` — so a preset would silently replace the
  // appended `--exclude-tags 'flutter || e2e'` and take the run OUT of the
  // bounded fast lane (the `all` preset re-admits the whole tree).
  final preset = requestedPresetArg(args);
  if (preset != null) {
    return FastSuiteDecision.refuse(
      preset.isEmpty
          ? 'run_fast_suite: the preset flag has no value.\n'
          : 'run_fast_suite: REFUSING preset "$preset".\n\n'
              "A preset's own selector configuration WINS over the CLI's "
              'tag selectors (package/test), so a preset would replace the '
              "fast lane's `--exclude-tags '$fastSuiteExcludeTags'` and take "
              'the run outside the bounded lane.\n\n'
              'Run the fast tier through this entrypoint (no preset):\n'
              '  dart run tools/run_fast_suite.dart\n\n'
              'Run a heavy tier directly, with its own lane:\n'
              '  dart test --preset=regression\n',
    );
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

  // The child is the SDK that is RUNNING this script, not a `dart` looked
  // up on PATH: `Process.start('dart', ...)` dies with an unhandled
  // ProcessException on any host whose PATH has no `dart` (this fleet has
  // lost its /usr/local/bin/dart symlink before).
  final process = await Process.start(
    Platform.resolvedExecutable,
    fastSuiteArgv(decision.command!),
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
