/// `StepRunner` — spawns the TDD step commands as sub-processes of the zfa
/// CLI and consumes their machine-readable contracts (spec 049-tdd-run,
/// FR-002 / U12-U18).
///
/// Each step runs as `tdd <step> <behavior-id>` plus `--feature <f>` and
/// `--project <dir>` flags through the resolved zfa entrypoint (a
/// sub-process, so a step crash cannot corrupt driver state). Success is
/// the step's exit code AND its documented summary line agreeing:
///
/// - `gen` — exit 0 (no summary-line requirement, U16);
/// - `verify-red` — exit 0 and `certified=true` (U13);
/// - `make` — exit 0 and `outcome=green`, `outcome=skipped` (U14;
///   `skipped` is the issue #694 already-green skip transition —
///   generation skipped, suite re-certified, green evidence appended),
///   or `outcome=green-with-failed-build` (issue #942 — a #737-tolerated
///   terminal build failure recorded honestly);
/// - `refactor` — exit 0 and `outcome=clean` or `outcome=refactored`
///   (U15).
///
/// The entrypoint is the `--zfa-bin` override when given (U18), else
/// resolved via `Platform.script` with `Isolate.resolvePackageUri` as
/// fallback (handles both normal CLI runs and test contexts). A `.dart`
/// entrypoint is AOT compiled through `ZfaExecutable.ensureCompiled` before
/// it is spawned (the no-JIT policy): every child is a compiled binary, and
/// the `dart <script>` shape survives only under `ZFA_ALLOW_JIT=1`.
///
/// Bug #690: when zfa is installed as a system binary (compiled exe or
/// pub-global snapshot), neither the script path nor the package path
/// resolves. The chain therefore adds the same system-binary tiers
/// #665 gave `PipelineRunner`: a concrete PATH lookup of `zfa`, and a
/// `Platform.resolvedExecutable` fallback (the running binary itself,
/// when it is not the Dart VM).
///
/// Bug #1636: the running-binary tier outranks the PATH tier. When the
/// driving process IS a compiled (non-VM) executable — the `scripts/zfa`
/// compile-cache artifact, or an install dir earlier/later on PATH — it is
/// definitionally what the operator invoked, and a same-version /
/// different-code PATH install is invisible to the #1472 version pin.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../cli/zfa_executable.dart';
import 'tdd_timeout.dart';
import 'step_timeout_receipt.dart';

/// Spawn hook so fast-tier tests can drive the parser without real
/// processes (the slow tier exercises the real spawn path with the
/// fixture's fake zfa binary).
typedef StepSpawner =
    Future<ProcessResult> Function(
      List<String> command,
      String workingDirectory,
    );

/// One step invocation's machine-readable outcome.
class StepResult {
  const StepResult({
    required this.step,
    required this.behaviorId,
    required this.exitCode,
    required this.outcome,
    required this.success,
    required this.output,
    required this.command,
    this.verdictKind,
    this.timeoutReceipt,
  });

  final String step;
  final String behaviorId;
  final int exitCode;

  /// The spawned command line, joined for display (issue #1329): the
  /// argv the runner actually executed — the entrypoint (with the `dart`
  /// prefix only under the `ZFA_ALLOW_JIT=1` escape hatch, see
  /// `ZfaExecutable.commandFor`), the step argv, and the baseline
  /// / timeout flags when handed off. Recorded verbatim by the run
  /// driver's error-outcome path so a failed step's evidence names what
  /// ran; never parsed (a display rendering, not a shell-quotable
  /// command).
  final String command;

  /// The step's outcome token: `ok`/`certified`/`green`/`clean`/
  /// `refactored` on success; the step's own failure class (its
  /// classification or outcome field) or `runner-error`/`missing-summary`
  /// otherwise.
  final String outcome;
  final bool success;

  /// The step's own verdict kind when the child reported a machine-
  /// parseable verdict (issue #992): gen refusals print the verdict JSON
  /// as their final stdout line — `verdict:"refused"` plus the lane
  /// `kind` — and the driver's per-kind degradation needs that kind.
  /// Null when the step printed no verdict (the common case).
  final String? verdictKind;

  /// The step's combined stdout + stderr (for failure reports).
  final String output;

  /// Spec 1529 (U7): the structured timeout diagnostics when the step
  /// child was killed at the deadline — argv, actual elapsed, deadline,
  /// phase inference, captured output tail. The run driver writes the
  /// durable receipt (`make.<id>.timeout.json`) from this data; every
  /// non-timeout path leaves it null.
  final StepTimeoutInfo? timeoutReceipt;

  @override
  String toString() =>
      'StepResult(step: $step, behavior: $behaviorId, exit: $exitCode, '
      'outcome: $outcome, success: $success)';
}

class StepRunner {
  /// [timeout] is the per-step deadline for the DEFAULT spawn path (bug
  /// #742): a hanging step child is killed and mapped to a `runner-error`
  /// [StepResult] instead of hanging the driver forever. Defaults to
  /// [TddTimeouts.defaultStepProcess]. Injected [spawner] fakes are the
  /// caller's responsibility (fast-tier tests), as before.
  ///
  /// [ensureCompiled] is the no-JIT seam: it resolves a `.dart` entrypoint
  /// to the AOT-compiled artifact before the child is shaped
  /// ([ZfaExecutable.ensureCompiled] by default). Fast-tier tests inject a
  /// fake so no real `dart compile exe` runs.
  StepRunner({
    this.zfaBin,
    StepSpawner? spawner,
    Duration? timeout,
    this.childEnvironment,
    this.onChildLine,
    ZfaEnsureCompiled? ensureCompiled,
  }) : timeout = timeout ?? TddTimeouts.defaultStepProcess,
       _ensureCompiled = ensureCompiled ?? ZfaExecutable.ensureCompiled,
       _spawner =
           spawner ??
           ((List<String> command, String workingDirectory) =>
               _timedDefaultSpawner(
                 command,
                 workingDirectory,
                 timeout ?? TddTimeouts.defaultStepProcess,
                 childEnvironment,
                 onChildLine,
               ));

  /// Explicit entrypoint override (`--zfa-bin`). When null the package
  /// root's `bin/zfa.dart` is resolved.
  final String? zfaBin;

  /// The effective per-step deadline (bug #742).
  final Duration timeout;

  final StepSpawner _spawner;
  final ZfaEnsureCompiled _ensureCompiled;

  /// Injected child environment (spec 1520): the caller's per-run scratch
  /// TMPDIR map (`ScratchTmpDir.childEnvironment`) handed to EVERY spawned
  /// step child through the default spawner, so `dart test` grandchildren
  /// write their `dart_test.kernel.*` dirs inside the run's own scratch
  /// instead of the shared user TMPDIR (issue #1520). Null — the default —
  /// preserves the inherit-`Platform.environment` behavior; an injected
  /// [StepSpawner] fake keeps its own contract (the env rides the REAL
  /// spawn path only).
  final Map<String, String>? childEnvironment;

  /// Issue #1590: the stdout line callback forwarded into `runTimed` by
  /// the DEFAULT spawner — every complete stdout line the step child
  /// prints fires this callback AS IT ARRIVES, which is how the driver
  /// forwards the make child's `→ ` sub-step banners to the run output
  /// while the step still runs. The captured `StepResult.output` is
  /// unchanged (the callback observes the stream; it never replaces the
  /// capture). Null (the default) keeps the pre-#1590 capture path.
  /// An injected [StepSpawner] fake keeps its own contract — the callback
  /// rides the REAL spawn path only (the established childEnvironment
  /// precedent).
  final void Function(String line)? onChildLine;

  /// Resolved entrypoint, cached after the first step so `defaultZfaBin`'s
  /// `Isolate.resolvePackageUri` lookup runs once per run, not once per step
  /// (minor finding from the review of #608).
  String? _resolvedEntry;

  static const stepOrder = ['gen', 'verify-red', 'make', 'refactor'];

  /// Resolve the zfa entrypoint the driver spawns when `--zfa-bin` is
  /// absent.
  ///
  /// Resolution order:
  ///   1. `Platform.script` when its basename is `zfa.dart` or `zuraffa.dart`
  ///      (running from the entrypoint directly).
  ///   2. `p.join(dirname(Platform.script), 'bin', 'zfa.dart')` — handles
  ///      compiled-snapshot / global-activate where the script is a sibling
  ///      of `bin/`.
  ///   3. `Isolate.resolvePackageUri` fallback — handles test contexts where
  ///      `Platform.script` points at the test runner.
  ///   4. `Platform.resolvedExecutable` when it is a compiled (non-Dart-VM)
  ///      executable — the RUNNING binary (bug #1636). It is definitionally
  ///      what the operator invoked, so it outranks the PATH tier: a
  ///      same-version/different-code PATH install (the `scripts/zfa`
  ///      compile-cache artifact driving the run, an install dir elsewhere
  ///      on PATH) is invisible to the #1472 version pin. This is the #690
  ///      final `resolvedExecutable`+`script` fallback promoted ahead of
  ///      PATH, its condition unchanged.
  ///   5. The system-installed `zfa` binary, resolved concretely from PATH
  ///      (bug #690 — the same tier #665 added to `PipelineRunner`).
  ///   6. `Platform.script` as a usable file (compiled snapshot).
  ///
  /// VM drivers (`dart run`, `dart test`, a `dartaotruntime` snapshot
  /// launch) fail the tier-4 non-VM check and keep the exact #690/#717
  /// order below — backward compatible (issue #1636 acceptance criterion 2).
  ///
  /// The resolved path is then passed through [ensureCompiled] (the no-JIT
  /// policy): a source resolution (`bin/zfa.dart` — tiers 1-3, the shape a
  /// source run and a `dart test` context produce) becomes the shared AOT
  /// artifact, while an already-compiled binary or a system install is
  /// returned unchanged. [environment] is the map both the resolution and
  /// the compile read (the `ZFA_ALLOW_JIT` escape hatch, the issue #1187
  /// scale); null reads `Platform.environment`.
  static Future<String> defaultZfaBin({
    ZfaEnsureCompiled? ensureCompiled,
    Map<String, String>? environment,
  }) async {
    final resolved = await resolveEntrypoint(
      script: Platform.script,
      resolvedExecutable: Platform.resolvedExecutable,
      environment: environment ?? Platform.environment,
    );
    return (ensureCompiled ?? ZfaExecutable.ensureCompiled)(
      resolved,
      environment: environment,
    );
  }

  /// The [defaultZfaBin] chain over injected inputs — visible for testing
  /// so every tier (including the bug #690 system-binary fallbacks and the
  /// bug #1636 running-binary tier) can be exercised without compiling a
  /// real binary.
  static Future<String> resolveEntrypoint({
    required Uri script,
    required String resolvedExecutable,
    required Map<String, String> environment,
    Future<Uri?> Function(Uri packageUri)? resolvePackageUri,
  }) async {
    final resolve = resolvePackageUri ?? Isolate.resolvePackageUri;
    if (script.scheme == 'file') {
      final scriptPath = script.toFilePath();
      final base = p.basename(scriptPath);
      if (base == 'zfa.dart' || base == 'zuraffa.dart') {
        // Running from bin/zfa.dart or bin/zuraffa.dart — already the entrypoint.
        // Issue #1371: only when it EXISTS. Under the global `-C <dir>`
        // chdir, the relative launch arg re-anchors Platform.script
        // against the new cwd, so the tier-1 path can name a file that
        // is not there — fall through to the package tier, which
        // resolves via the package config and is immune to the chdir.
        if (await File(scriptPath).exists()) return scriptPath;
      }
      // Running from a compiled snapshot or sibling path.
      final derived = p.join(p.dirname(scriptPath), 'bin', 'zfa.dart');
      if (await File(derived).exists()) return derived;
      // Fall through: the derived path may not exist (e.g. test runner).
    }
    // Fallback: resolve via the package path (handles test contexts where
    // Platform.script points at the test kernel).
    final uri = await resolve(Uri.parse('package:zuraffa/src/zfa_cli.dart'));
    if (uri != null) {
      // <pkg>/lib/src/zfa_cli.dart -> <pkg>/bin/zfa.dart
      final bin = p.join(
        p.dirname(p.dirname(p.dirname(p.fromUri(uri)))),
        'bin',
        'zfa.dart',
      );
      if (await File(bin).exists()) return bin;
    }
    // Tier 4 (bug #1636): the RUNNING binary. When this process runs as a
    // compiled (non-VM) executable, the executable IS the zfa entrypoint —
    // the same resolvedExecutable fallback bug #690 introduced, promoted
    // AHEAD of the PATH tier: the PATH install may predate the driving
    // build while carrying the same version string, which the #1472 pin
    // cannot distinguish, so the only safe resolution for a compiled
    // driver is the binary driving the run. The Dart VM names are excluded
    // so a source/test/snapshot context (dart run, dart test,
    // dartaotruntime) never spawns the bare VM with step argv and keeps
    // the exact #690/#717 order below.
    if (!_isDartVmName(p.basename(resolvedExecutable)) &&
        await File(resolvedExecutable).exists()) {
      return resolvedExecutable;
    }
    // Tier 5 (bug #690): the system-installed `zfa` binary on PATH —
    // resolved concretely, no shell, mirroring #665's tier for the
    // pipeline runner. This is the tier that makes a system-installed
    // zfa work without --zfa-bin for a VM driver.
    final onPath = _findExecutableOnPath('zfa', environment['PATH']);
    if (onPath != null) return onPath;
    // Tier 6: Platform.script as a usable file (compiled snapshot).
    if (script.scheme == 'file') {
      final scriptPath = script.toFilePath();
      if (await File(scriptPath).exists()) return scriptPath;
    }
    throw StateError(
      'cannot resolve the zfa entrypoint (package:zuraffa is not on the '
      'package path and Platform.script is not a usable file); '
      'pass --zfa-bin explicitly',
    );
  }

  /// Whether [basename] is a Dart VM executable rather than a compiled
  /// zfa binary (bug #690): `dart`, `dartvm`, `dartaotruntime` and their
  /// `.exe` variants.
  static bool _isDartVmName(String basename) {
    const names = {'dart', 'dartvm', 'dartaotruntime'};
    final lower = basename.toLowerCase();
    return names.contains(lower) || names.any((name) => lower == '$name.exe');
  }

  /// Resolve the concrete executable [name] from the [path] environment
  /// variable without a shell (mirrors `PipelineRunner`'s #665 lookup).
  /// Returns null when [path] is empty or no executable candidate exists.
  static String? _findExecutableOnPath(String name, String? path) {
    if (path == null || path.isEmpty) return null;
    final extensions = Platform.isWindows
        ? (Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD')
              .split(';')
              .where((extension) => extension.isNotEmpty)
        : const [''];
    for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
      if (directory.isEmpty) continue;
      for (final extension in extensions) {
        final candidate = File(p.join(directory, '$name$extension'));
        if (!candidate.existsSync()) continue;
        if (Platform.isWindows || (candidate.statSync().mode & 0x49) != 0) {
          return candidate.path;
        }
      }
    }
    return null;
  }

  /// Run one step for [behaviorId] and map the sub-process result onto the
  /// step's contract. A spawn failure yields a `runner-error` StepResult,
  /// never a crash (U17).
  ///
  /// [feature] is the canonical feature REFERENCE the child resolves (issue
  /// #1471): the driver hands the same reference it resolved, so a bug
  /// feature (`.specify/bugs/<slug>`) resolves to the identical directory
  /// in the child. For a plain feature name the reference IS the name.
  Future<StepResult> run({
    required String step,
    required String behaviorId,
    required String feature,
    required String projectRoot,
    String? suiteBaselinePath,
    Set<String> parkedSeamPaths = const {},
    Set<String> parkedFailureIdentifiers = const {},
    List<String> extraArgs = const [],
  }) async {
    if (!stepOrder.contains(step)) {
      throw ArgumentError.value(step, 'step', 'unknown TDD step');
    }
    // No-JIT policy: the `--zfa-bin` override is compiled here too, so a
    // `.dart` override can never reach the spawner un-compiled.
    final entry = _resolvedEntry ??= zfaBin != null
        ? await _ensureCompiled(zfaBin!)
        : await defaultZfaBin(ensureCompiled: _ensureCompiled);
    final argv = [
      'tdd',
      step,
      behaviorId,
      '--feature',
      feature,
      '--project',
      projectRoot,
    ];
    // Issue #741: hand the run's cached suite baseline to make steps so
    // the full suite runs once per run, not once per behavior. Issue #922:
    // refactor steps get the same handoff — the spawned preflight and
    // re-proof exclude the baseline's pre-existing red from their verdicts,
    // so 24 pre-existing failures in unrelated files cannot refuse every
    // refactor and stop the run at green=13 done=0. A flag-less standalone
    // refactor keeps the absolute-green contract (spec 048 FR-001).
    if ((step == 'make' || step == 'refactor') &&
        suiteBaselinePath != null &&
        suiteBaselinePath.isNotEmpty) {
      argv.addAll(['--suite-baseline', suiteBaselinePath]);
    }
    // Issue #1589: hand the parked contracts' seam files to refactor
    // spawns — the gate tolerates suite failures inside those files (the
    // BLOCKED verdict's pre-existing red, the same economics issue #922
    // gave the baseline). The driver only ever passes seams it SAW parked
    // (or loaded from a persisted verdict receipt), so the flag is the
    // driver's attestation. Review fix: the driver also hands the failing
    // identifiers each verdict RECORDED (`--parked-failure`), so the gate
    // pins its tolerance to the known red instead of exempting every
    // failure in the seam file. A flag-less standalone refactor keeps the
    // absolute-green contract (spec 048 FR-001).
    if (step == 'refactor' && parkedSeamPaths.isNotEmpty) {
      for (final seam in parkedSeamPaths) {
        if (seam.isEmpty) continue;
        argv.addAll(['--parked-seam', seam]);
      }
    }
    if (step == 'refactor' && parkedFailureIdentifiers.isNotEmpty) {
      for (final identifier in parkedFailureIdentifiers) {
        if (identifier.isEmpty) continue;
        argv.addAll(['--parked-failure', identifier]);
      }
    }
    // Issue #1159: the driver's deadline is ONE uniform deadline (bug #742)
    // — the spawned step child must inherit it, otherwise make/refactor
    // fall back to their internal 10-minute defaults and their baseline
    // suite is killed mid-run on repos whose fast suite runs long.
    if (timeout != TddTimeouts.defaultStepProcess) {
      argv.addAll([
        '--timeout',
        (timeout.inMicroseconds / Duration.microsecondsPerMinute)
            .toStringAsFixed(4),
      ]);
    }
    // Issue #1588: driver-passed step flags (the phase-2 refactor pass's
    // --pass-batch / --exempt-behaviors batch context). Appended verbatim
    // after the baseline/timeout flags; the default is empty so every
    // existing call site (gen / verify-red / make / phase-1 refactor)
    // spawns byte-identical argv as before.
    if (extraArgs.isNotEmpty) {
      argv.addAll(extraArgs);
    }
    // No-JIT policy: `commandFor` shapes the child argv — the `dart` prefix
    // is reachable only under the explicit `ZFA_ALLOW_JIT=1` escape hatch,
    // which is also the only way a `.dart` entry survives `ensureCompiled`.
    final command = ZfaExecutable.commandFor(entry, argv);
    // Issue #1329: the display rendering every StepResult carries — the
    // driver's error-outcome recording records what actually ran.
    final commandLine = command.join(' ');

    final ProcessResult process;
    try {
      process = await _spawner(command, projectRoot);
    } on ProcessTimeoutException catch (e) {
      // Bug #742: the step child outlived the deadline and was killed.
      // runner-error, never a hang, never a silent success.
      //
      // Spec 1529 (U7): the kill is no longer diagnose-blind — the
      // structured diagnostics (argv, ACTUAL elapsed, deadline, phase,
      // captured tail) ride the result; the driver writes the durable
      // receipt from them.
      final phase = inferTimeoutPhase(
        descendantArgvs: e.descendantArgvs,
        output: e.output,
      );
      return StepResult(
        step: step,
        behaviorId: behaviorId,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: e.toString(),
        command: commandLine,
        timeoutReceipt: StepTimeoutInfo(
          behaviorId: behaviorId,
          step: step,
          argv: command,
          elapsed: e.elapsed,
          deadline: e.timeout,
          phase: phase,
          outputTail: e.output,
          workingDirectory: e.workingDirectory,
        ),
      );
    } on ProcessException catch (e) {
      return StepResult(
        step: step,
        behaviorId: behaviorId,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: 'spawn failed for ${command.first}: ${e.message}',
        command: commandLine,
      );
    } on IOException catch (e) {
      return StepResult(
        step: step,
        behaviorId: behaviorId,
        exitCode: -1,
        outcome: 'runner-error',
        success: false,
        output: 'spawn failed for ${command.first}: $e',
        command: commandLine,
      );
    }

    final stdout = process.stdout.toString();
    final stderr = process.stderr.toString();
    final output = stderr.isEmpty ? stdout : '$stdout\n$stderr';
    final kv = _parseSummaryLine(step, stdout);
    final exitOk = process.exitCode == 0;

    switch (step) {
      case 'gen':
        // Issue #992: a refused child (issue #938 widget gate) reports
        // its machine-parseable verdict JSON as the final stdout line —
        // surface the verdict token and the lane kind so the driver can
        // degrade per-kind instead of staring at a generic `error`.
        final refusal = exitOk ? null : _parseGenVerdict(stdout);
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: exitOk ? 'ok' : (refusal?['verdict'] ?? 'error'),
          verdictKind: refusal?['kind'],
          success: exitOk,
          output: output,
          command: commandLine,
        );
      case 'verify-red':
        final certified = kv != null && kv['certified'] == 'true';
        final outcome = certified
            ? 'certified'
            : (kv?['classification'] ??
                  (exitOk ? 'missing-summary' : 'failed'));
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: outcome,
          success: exitOk && certified,
          output: output,
          command: commandLine,
        );
      case 'make':
      case 'refactor':
        final outcome =
            kv?['outcome'] ?? (exitOk ? 'missing-summary' : 'failed');
        final success =
            exitOk &&
            (step == 'make'
                ? // `green` is the certified generation outcome;
                  // `skipped` is the issue #694 already-green skip
                  // transition (generation skipped, suite re-certified,
                  // green evidence appended by make itself);
                  // `green-with-failed-build` is the issue #942 honest
                  // label for a #737-tolerated terminal build failure —
                  // the loop must flow past tolerated noise, but the
                  // accounting stays distinguishable from real green;
                  // `adopted` is the issue #1331 re-drive transition —
                  // the last reset tombstone invalidated the surviving
                  // certification and the make adopted the passing
                  // subject (green evidence appended by make itself).
                  // `adopted-placeholder` is the issue #1345 compose
                  // re-entry — the tombstoned acceptance re-drive whose
                  // on-disk subject was the born-green pipeline
                  // placeholder re-entered the acceptance pipeline at
                  // compose/make phase-2 and re-certified from the
                  // pipeline's actual output (green evidence appended by
                  // make itself).
                  // `born-green` is the issue #1411 hand-first
                  // transition — the designed hand step (real outcome
                  // assertion, marker removed, subject
                  // hand-implemented) completed BEFORE the first red
                  // certification, certified green by the explicit
                  // `--born-green` make flag from an honestly re-run
                  // passing target test (green evidence appended by
                  // make itself in the existing format).
                  outcome == 'green' ||
                      outcome == 'skipped' ||
                      outcome == 'green-with-failed-build' ||
                      outcome == 'adopted' ||
                      outcome == 'adopted-placeholder' ||
                      outcome == 'born-green'
                : outcome == 'clean' || outcome == 'refactored');
        return StepResult(
          step: step,
          behaviorId: behaviorId,
          exitCode: process.exitCode,
          outcome: outcome,
          success: success,
          output: output,
          command: commandLine,
        );
    }
    // Unreachable: step validated against stepOrder above.
    throw StateError('unhandled step $step');
  }

  /// The last `<step>: key=value ...` line in [stdout], parsed into a map —
  /// the step commands' machine contract (FR-002). Returns null when the
  /// step printed no summary line.
  static Map<String, String>? _parseSummaryLine(String step, String stdout) {
    Map<String, String>? last;
    for (final line in stdout.split('\n')) {
      if (!line.startsWith('$step: ')) continue;
      final fields = <String, String>{};
      for (final match in RegExp(
        r'(\w+)=([^\s]+)',
      ).allMatches(line.substring(step.length + 2))) {
        fields[match.group(1)!] = match.group(2)!;
      }
      last = fields;
    }
    return last;
  }

  /// The gen child's machine-parseable verdict, parsed from the LAST
  /// stdout line that decodes as a JSON object naming `command:"gen"`
  /// (issue #938's contract: the verdict JSON stays the final stdout
  /// line). Returns null when stdout carries no gen verdict — the common
  /// case for ok, and for failures that predate the verdict JSON.
  static Map<String, String>? _parseGenVerdict(String stdout) {
    for (final line in stdout.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic> &&
            decoded['command'] == 'gen' &&
            decoded['verdict'] is String) {
          return {
            'verdict': decoded['verdict'] as String,
            if (decoded['kind'] is String) 'kind': decoded['kind'] as String,
          };
        }
      } on FormatException {
        // Not JSON — keep scanning (a child may print bracketed prose).
      }
    }
    return null;
  }

  /// The default spawn path with a hard deadline (bug #742): the child is
  /// killed at [timeout] and a [ProcessTimeoutException] propagates to
  /// [run], which maps it to a `runner-error` StepResult. [environment] is
  /// the caller's scratch-TMPDIR map (spec 1520) — merged over the
  /// inherited environment, null inherits it unchanged. [onChildLine] is
  /// the issue #1590 stdout line tee (null keeps the plain capture).
  static Future<ProcessResult> _timedDefaultSpawner(
    List<String> command,
    String workingDirectory,
    Duration timeout,
    Map<String, String>? environment,
    void Function(String line)? onChildLine,
  ) {
    return runTimed(
      command.first,
      command.sublist(1),
      workingDirectory: workingDirectory,
      timeout: timeout,
      environment: environment,
      onStdoutLine: onChildLine,
    );
  }
}
