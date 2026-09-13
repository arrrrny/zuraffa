/// Per-command subprocess deadlines + the timed-spawn primitive (bug #742).
///
/// Bug #742: none of the TDD subsystem's `Process.run` invocations passed a
/// timeout, so a hanging `dart test` / `zfa build` / `zfa tdd func` child
/// made the runner hang forever (`zfa tdd make U4` never returned). This
/// library gives every TDD subprocess invocation a hard deadline:
///
///   1. [TddTimeouts] — the per-command defaults, generous by design (a
///      timeout that is too short causes spurious failures on slow CI
///      machines; the assessment's remediation names 10 min for a full
///      suite and 2 min for a single test), overridable by the
///      `--timeout <minutes>` flag on the spawning commands.
///   2. [runTimed] — the timed-spawn primitive every TDD call site uses in
///      place of bare `Process.run`. When the child outlives the deadline
///      it is killed (SIGKILL on POSIX, TerminateProcess on Windows), the
///      output captured so far is preserved, and a
///      [ProcessTimeoutException] is thrown so the call site can map the
///      outcome to its runnerError/timeout class and print a clear message
///      naming the behavior, step, and command.
///
/// Note: Dart's `Process.run` has NO timeout parameter (checked SDK
/// 3.13.x), so the deadline is enforced here with `Process.start` + a
/// raced `exitCode.timeout` + kill — the child is really killed, not
/// merely abandoned.
library;

import 'dart:async';
import 'dart:io';

/// Deadline configuration for every TDD subprocess invocation (bug #742).
class TddTimeouts {
  const TddTimeouts({
    this.singleTest = defaultSingleTest,
    this.suite = defaultSuite,
    this.pipelineStep = defaultPipelineStep,
    this.stepProcess = defaultStepProcess,
    this.refactorPass = defaultRefactorPass,
    this.mutationPreflight = defaultMutationPreflight,
    this.mutationRun = defaultMutationRun,
    this.probe = defaultProbe,
  });

  /// A single target test (`zfa tdd verify-red`, the make drift check /
  /// post-generation re-run).
  static const defaultSingleTest = Duration(minutes: 2);

  /// The full suite (make baseline + guard, verify-red re-certification).
  static const defaultSuite = Duration(minutes: 10);

  /// One generation pipeline step (`zfa entity create` / `zfa make` /
  /// `zfa build`).
  static const defaultPipelineStep = Duration(minutes: 10);

  /// One driver/corpus step process (`zfa tdd gen|verify-red|make|refactor`
  /// / `zfa tdd run|verify` spawned by the driver or the corpus harness).
  static const defaultStepProcess = Duration(minutes: 10);

  /// One refactor pass (build / format / fix).
  static const defaultRefactorPass = Duration(minutes: 10);

  /// The mutation audit's green-suite preflight (`dart test <scope>`).
  static const defaultMutationPreflight = Duration(minutes: 10);

  /// The mutation run itself (`dart run mutation_test`) — the slowest TDD
  /// child by design (one test execution per mutant).
  static const defaultMutationRun = Duration(minutes: 30);

  /// Tool availability probes (`dart --version`).
  static const defaultProbe = Duration(seconds: 30);

  /// The per-step budget FLOOR (spec 1529): the issue's own idle-machine
  /// calibration. The run driver's DEFAULT per-step budget never drops
  /// below this — a fixed 10-minute default was measured as UNSAFE under
  /// concurrent load (the U8 misfire), and the floor is the minimum
  /// calibration that keeps fast suites safe while the measured-baseline
  /// scaling handles the slow ones.
  static const minStepBudget = Duration(minutes: 25);

  /// The budget-scaling MULTIPLE (spec 1529): a make step's projected
  /// cost is bounded by 4x the measured baseline suite duration — the
  /// issue's calibration for "the step re-runs a suite that grows every
  /// behavior, under load".
  static const budgetMultiple = 4;

  final Duration singleTest;
  final Duration suite;
  final Duration pipelineStep;
  final Duration stepProcess;
  final Duration refactorPass;
  final Duration mutationPreflight;
  final Duration mutationRun;
  final Duration probe;

  /// The `--timeout <minutes>` override: replaces every per-command default
  /// with one uniform deadline for all subprocesses the command spawns.
  factory TddTimeouts.uniform(Duration deadline) => TddTimeouts(
    singleTest: deadline,
    suite: deadline,
    pipelineStep: deadline,
    stepProcess: deadline,
    refactorPass: deadline,
    mutationPreflight: deadline,
    mutationRun: deadline,
    probe: deadline,
  );
}

/// Parses the `--timeout <minutes>` flag value (bug #742).
///
/// `null`/empty → `null` (the command's per-command defaults apply).
/// Fractions are allowed (`0.5` = 30 s). Anything else that is not a
/// positive number of minutes throws [TddTimeoutFormatException] so the
/// command can reject it non-zero instead of guessing.
Duration? parseTddTimeoutMinutes(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final minutes = double.tryParse(raw);
  if (minutes == null || minutes <= 0) {
    throw TddTimeoutFormatException(raw);
  }
  return Duration(
    microseconds: (minutes * Duration.microsecondsPerMinute).round(),
  );
}

/// Thrown when the `--timeout` flag value is not a positive number of
/// minutes.
class TddTimeoutFormatException implements Exception {
  TddTimeoutFormatException(this.raw);

  /// The invalid flag value as given.
  final String raw;

  String get message =>
      'invalid --timeout "$raw": pass a positive number of minutes '
      '(fractions allowed, e.g. 0.5 for 30 seconds).';

  @override
  String toString() => message;
}

/// Thrown by [runTimed] when the child outlives [timeout] (bug #742).
///
/// The child has already been killed (SIGKILL on POSIX, TerminateProcess on
/// Windows) and reaped when this is thrown; [output] carries whatever it
/// wrote before the kill so the failure report stays actionable.
///
/// Spec 1529: [elapsed] is the child's ACTUAL wall-clock lifetime (the
/// configured deadline is [timeout] — the two differ when scheduling
/// delays the kill), and [descendantArgvs] is the best-effort snapshot of
/// the child's descendant process tree taken at the deadline (POSIX `ps`;
/// empty when the platform cannot observe it or the probe failed) — the
/// diagnostics that let a killed make step's receipt say WHERE the child
/// was instead of "hung somewhere".
class ProcessTimeoutException implements Exception {
  ProcessTimeoutException({
    required this.executable,
    required this.arguments,
    required this.timeout,
    required this.workingDirectory,
    required this.output,
    Duration? elapsed,
    this.descendantArgvs = const [],
  }) : elapsed = elapsed ?? timeout;

  final String executable;
  final List<String> arguments;

  /// The deadline that fired.
  final Duration timeout;

  /// The child's actual wall-clock lifetime until the kill (spec 1529).
  final Duration elapsed;

  /// The descendant process argv lines observed at the deadline, one
  /// process per line (just the args, for portability) — best-effort
  /// diagnostics, empty when unobservable (spec 1529).
  final List<String> descendantArgvs;

  /// The working directory the child ran in, when known.
  final String? workingDirectory;

  /// stdout + stderr captured before the kill.
  final String output;

  /// The command line as it was invoked (post-resolution).
  String get commandDisplay => [executable, ...arguments].join(' ');

  @override
  String toString() {
    final buf = StringBuffer()
      ..write(
        'Subprocess TIMED OUT after ${formatTddTimeout(elapsed)} and was '
        'killed (SIGKILL): `$commandDisplay`',
      );
    if (workingDirectory != null && workingDirectory!.isNotEmpty) {
      buf.write(' (working directory: $workingDirectory)');
    }
    final captured = output.trim();
    if (captured.isNotEmpty) {
      final lines = captured.split('\n');
      final tail = lines.length > 10
          ? lines.sublist(lines.length - 10).join('\n')
          : captured;
      buf
        ..writeln()
        ..write('   captured output before the kill (tail):\n   $tail');
    }
    return buf.toString();
  }
}

/// Human-readable duration for timeout messages: `45s`, `2m00s`, `10m00s`.
String formatTddTimeout(Duration d) {
  if (d.inMinutes == 0) return '${d.inSeconds}s';
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}m${seconds}s';
}

/// Human-readable duration for BUDGET warnings (spec 1529): sub-minute
/// budgets keep one decimal of second precision (`1.2s`, `4.8s`) — the
/// loud warning must name numbers the operator can compare at a glance;
/// minute-plus budgets render as `2.50m`.
String formatBudget(Duration d) {
  if (d.inMinutes == 0) {
    final seconds = d.inMicroseconds / Duration.microsecondsPerSecond;
    return '${seconds.toStringAsFixed(1)}s';
  }
  final minutes = d.inMicroseconds / Duration.microsecondsPerMinute;
  return '${minutes.toStringAsFixed(2)}m';
}

/// Runs [executable] with [arguments] under a hard [timeout] (bug #742)
/// and — on POSIX — an optional address-space ceiling (bug #826).
///
/// Drop-in replacement for `Process.run` at every TDD spawn site:
///
///   * spawn failure throws [ProcessException] exactly like `Process.run`;
///   * a child that finishes within [timeout] returns the same
///     [ProcessResult] `Process.run` would have returned (systemEncoding
///     decoding, combined-capture semantics preserved by the caller);
///   * a child that outlives [timeout] is KILLED (SIGKILL), reaped, and a
///     [ProcessTimeoutException] carrying the output captured so far is
///     thrown — no TDD subprocess may await a child indefinitely.
///
/// Bug #826: when [memoryLimitKb] is set and the platform is not Windows,
/// the child spawns through `sh -c 'ulimit -v <kb>; exec "$0" "$@"'` so
/// the ceiling is enforced by the kernel INSIDE the child while the spawn
/// argv (and every captured/displayed command line) stays the original
/// one. `exec` replaces the shell, so the PID [runTimed] later kills at
/// the deadline is the real child, and the child's exit is the child's
/// own — a runaway allocation becomes a deterministic in-child abort
/// (classified `resource-limit` by the caller) instead of a
/// nondeterministic OS OOM kill of whatever process happens to be in
/// memory pressure at the time. macOS notes: `ulimit -v` is accepted by
/// the shell but not kernel-enforced there, so the bound is best-effort —
/// the deadline and the classified-verdict contract still hold. Windows
/// has no ulimit equivalent; [memoryLimitKb] is ignored there.
Future<ProcessResult> runTimed(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell = false,
  required Duration timeout,
  int? memoryLimitKb,
}) async {
  // Bug #826: wrap the spawn under a kernel-enforced address-space
  // ceiling. Shell-wrapper mode requires direct execution (no shell of
  // our own) and a POSIX sh; anything else spawns unbounded.
  var spawnExecutable = executable;
  var spawnArguments = arguments;
  final bounded = memoryLimitKb != null && !Platform.isWindows && !runInShell;
  if (bounded) {
    spawnExecutable = 'sh';
    spawnArguments = [
      '-c',
      'ulimit -v $memoryLimitKb 2>/dev/null; exec "\$0" "\$@"',
      executable,
      ...arguments,
    ];
  }
  final process = await Process.start(
    spawnExecutable,
    spawnArguments,
    workingDirectory: workingDirectory,
    runInShell: runInShell,
  );
  final stdoutFuture = process.stdout.transform(systemEncoding.decoder).join();
  final stderrFuture = process.stderr.transform(systemEncoding.decoder).join();
  // Spec 1529: the child's ACTUAL lifetime, measured — the configured
  // deadline ([timeout]) and the kill's wall time differ under load.
  final stopwatch = Stopwatch()..start();
  var killed = false;
  List<String> descendants = const [];
  int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    killed = true;
    // Spec 1529: snapshot the child's descendant tree BEFORE the kill —
    // after the SIGKILL the tree is gone and the receipt could only say
    // "hung somewhere". Best-effort: an unobservable tree (Windows, a
    // ps-less PATH, a raced exit) yields an empty snapshot, never a
    // failure of the kill path itself.
    descendants = await _snapshotDescendantArgvs(process.pid);
    // Kill (SIGKILL on POSIX) and reap so no zombie survives the deadline.
    // After `exec` the shell PID IS the child PID, so the kill lands on
    // the real subprocess in the bounded path too.
    process.kill(ProcessSignal.sigkill);
    exitCode = await process.exitCode;
  }
  stopwatch.stop();
  final stdoutText = await stdoutFuture;
  final stderrText = await stderrFuture;
  if (killed) {
    throw ProcessTimeoutException(
      executable: executable,
      arguments: arguments,
      timeout: timeout,
      workingDirectory: workingDirectory,
      output: '$stdoutText$stderrText',
      elapsed: stopwatch.elapsed,
      descendantArgvs: descendants,
    );
  }
  return ProcessResult(process.pid, exitCode, stdoutText, stderrText);
}

/// One process line of the descendant snapshot: `pid ppid args` collapsed
/// to just the args (the operator reads commands, not pids).
final RegExp _psArgsField = RegExp(r'^\s*\d+\s+\d+\s+(.*)$');

/// Best-effort snapshot of [pid]'s descendant process tree, one argv line
/// per descendant (spec 1529). POSIX-only (`ps`); every failure mode —
/// Windows, a missing `ps`, a raced exit — degrades to an EMPTY list:
/// diagnostics must never break the kill path they observe.
Future<List<String>> _snapshotDescendantArgvs(int pid) async {
  if (Platform.isWindows) return const [];
  try {
    final result = await Process.run('ps', const [
      '-eo',
      'pid,ppid,args',
    ]).timeout(const Duration(seconds: 5));
    if (result.exitCode != 0) return const [];
    final lines = result.stdout.toString().split('\n');
    // Parse "PID PPID ARGS" rows into a parent → children index.
    final argsOf = <int, String>{};
    final childrenOf = <int, List<int>>{};
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      final rowPid = int.tryParse(parts[0]);
      final rowPpid = int.tryParse(parts[1]);
      if (rowPid == null || rowPpid == null) continue;
      final argsMatch = _psArgsField.firstMatch(line);
      argsOf[rowPid] = argsMatch?.group(1) ?? parts.sublist(2).join(' ');
      childrenOf.putIfAbsent(rowPpid, () => <int>[]).add(rowPid);
    }
    // Walk the tree from [pid] down, collecting every descendant's argv.
    final argvs = <String>[];
    final queue = <int>[...childrenOf[pid] ?? const <int>[]];
    final seen = <int>{pid};
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!seen.add(current)) continue;
      final args = argsOf[current];
      if (args != null && args.isNotEmpty) argvs.add(args);
      queue.addAll(childrenOf[current] ?? const <int>[]);
    }
    return argvs;
  } on Exception {
    return const [];
  }
}

/// The derived per-step budget (spec 1529, US2): the deadline the run
/// driver hands every step child when the operator did not override it.
///
/// `max(floor, 4 x measured baseline)` — a make step's cost is bounded by
/// the suite it re-certifies against, and that suite grows every behavior
/// (the issue's quadratic-growth observation), so the budget scales from
/// the suite baseline the driver already measures once per run. A null
/// [measuredBaseline] (no fresh capture, no recorded duration in the
/// cache) degrades to the floor — never to the old fixed 10-minute
/// default that killed the dogfood run's U8.
///
/// An [explicit] budget (the operator's `--timeout`) ALWAYS wins: the
/// flag is the override; the driver warns loudly about an unsafe
/// explicit budget instead of silently overriding the operator.
Duration scaledStepBudget({Duration? measuredBaseline, Duration? explicit}) {
  if (explicit != null) return explicit;
  if (measuredBaseline == null) return TddTimeouts.minStepBudget;
  final scaled = Duration(
    microseconds: measuredBaseline.inMicroseconds * TddTimeouts.budgetMultiple,
  );
  return scaled > TddTimeouts.minStepBudget
      ? scaled
      : TddTimeouts.minStepBudget;
}

/// The projected make-step cost used for the loud-warning comparison:
/// `4 x [measuredBaseline]`, or null when nothing was measured.
Duration? projectedMakeCost({Duration? measuredBaseline}) {
  if (measuredBaseline == null) return null;
  return Duration(
    microseconds: measuredBaseline.inMicroseconds * TddTimeouts.budgetMultiple,
  );
}

/// One phase inference outcome: the phase token plus the evidence it was
/// derived from — the receipt NEVER presents a guess as an observation
/// (spec 1529 FR-3). `phase` is `compiling`, `running`, or `unknown`.
class PhaseVerdict {
  final String phase;
  final String evidence;

  const PhaseVerdict({required this.phase, required this.evidence});

  @override
  String toString() => '$phase ($evidence)';
}

/// Marker substrings identifying a TEST-RUNNER descendant: the killed
/// child was RUNNING tests (the dogfood's `flutter_tester` case).
const _testRunnerMarkers = [
  'flutter_tester',
  'dart test',
  'flutter test',
  'flutter_test',
];

/// Marker substrings identifying a COMPILE/kernel/build descendant: the
/// killed child was still COMPILING (kernel snapshots, build_runner,
/// dart compile, the VM's frontend server).
const _compileMarkers = [
  'frontend_server',
  'build_runner',
  'dart compile',
  'kernel_snapshot',
  'gen_kernel',
  'dartdev run_kernel',
];

/// Marker substrings in CAPTURED OUTPUT that prove a test run had begun
/// (the compact/file reporters' progress lines and summaries).
final RegExp _testProgressPattern = RegExp(
  r'^\d{2}:\d{2} \+\d+|^\d+:\d+ |All tests passed|Some tests failed|'
  r'loading (test|\.)|-[0-9]+: ',
  multiLine: true,
);

/// Infers WHERE a killed child was, from the best evidence available
/// (spec 1529, US1 / FR-3):
///
/// 1. the descendant process tree (POSIX `ps` snapshot) — a test-runner
///    descendant grades `running`, a compile/kernel descendant grades
///    `compiling`, and the tree evidence OUTRANKS the output markers
///    (a silent `flutter test` run emits nothing);
/// 2. captured-output test-progress markers grade `running`;
/// 3. no observable signal grades `unknown` — honestly (the receipt
///    records that nothing was observable, it does not guess).
PhaseVerdict inferTimeoutPhase({
  List<String> descendantArgvs = const [],
  String output = '',
}) {
  final tree = descendantArgvs.join('\n');
  if (tree.isNotEmpty) {
    for (final marker in _testRunnerMarkers) {
      if (tree.contains(marker)) {
        return PhaseVerdict(
          phase: 'running',
          evidence:
              'descendant argv matches test-runner marker '
              '"$marker": ${descendantArgvs.firstWhere((a) => a.contains(marker))}',
        );
      }
    }
    for (final marker in _compileMarkers) {
      if (tree.contains(marker)) {
        return PhaseVerdict(
          phase: 'compiling',
          evidence:
              'descendant argv matches compile marker "$marker": '
              '${descendantArgvs.firstWhere((a) => a.contains(marker))}',
        );
      }
    }
    return PhaseVerdict(
      phase: 'unknown',
      evidence:
          'descendant snapshot observable but matches no known '
          'test-runner or compile marker',
    );
  }
  if (_testProgressPattern.hasMatch(output)) {
    return PhaseVerdict(
      phase: 'running',
      evidence: 'captured output carries test-progress markers',
    );
  }
  return PhaseVerdict(
    phase: 'unknown',
    evidence:
        'no descendant snapshot and no test-progress output — '
        'the child produced no observable signal before the kill',
  );
}
