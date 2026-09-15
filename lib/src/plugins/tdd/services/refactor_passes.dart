/// `RefactorPasses` — the fixed pass registry + executor for
/// `zfa tdd refactor` (spec 048-tdd-refactor, T006; behaviors U1-U5).
///
/// The registry is a small, deliberately fixed set of idempotent
/// tool-driven normalization passes, executed in order:
///
///   1. `build`  — the resolved zfa entrypoint + `build` (codegen
///      normalization). Bug #689: this pass previously hardcoded
///      `dart run bin/zfa.dart build`, but `zfa setup` never creates
///      `bin/zfa.dart` in the project (it installs the system zfa), so
///      the pass — and therefore every refactor — misfired. The
///      entrypoint now resolves through the same tiers make/gen/verify
///      use via [PipelineRunner] (FR-004 / U11): `--zfa-bin` override →
///      the running CLI from source (Platform.script basename
///      zfa.dart/zuraffa.dart) → `zfa` on PATH → the dart+script
///      fallback. A source resolution is AOT compiled through
///      `ZfaExecutable.ensureCompiled` before the pass runs — no-JIT
///      policy: the build child is a compiled binary.
///   2. `format` — `dart format lib/`
///   3. `fix`    — `dart fix --apply lib/`
///
/// Each pass is executed via an injectable [ProcessExecutor] so tests can
/// drive the registry without real subprocesses. The executor records each
/// invocation; for each pass, the registry captures a [RefactorAction] with
/// `filesChanged` computed from a per-pass before/after tree-snapshot diff
/// scoped to `lib/`. The first failing pass stops the remaining passes
/// (spec 048 FR-010 — misfire-stop) — with ONE issue #1472 exception: the
/// build pass's WARNINGS-ONLY analyze-gate refusal (0 error(s) and >=1
/// warning(s), the #1407 machine contract cross-checked through the shared
/// `BuildCommand` parser) is logged with its accurate counts and does not
/// stop the registry — warnings are the `dart fix` pass's input, not
/// compile failures, and the pass that would clean them must run. Analyzer
/// errors, any other failure class, a spawn failure, or a timeout keep the
/// honest misfire-stop. The TDD profile's `analyze-gate: warnings-blocking`
/// opt-in (read by the command, handed in as [RefactorPasses.warningsBlocking])
/// restores the legacy refusal. The build pass's zfa entrypoint is pinned
/// to the version driving the run ([_pinToDrivingVersion]): a system zfa
/// on PATH whose `--version` provably disagrees with the running CLI is
/// bypassed in favor of the driving CLI's own entrypoint.
///
/// Issue #1624 — the build pass's scheduling gate. The refactor's
/// whole-project `zfa build` (build_runner + the whole-project `dart
/// analyze lib/`) is pure overhead on a feature whose generation writes
/// only plain Dart. A [RefactorPassSpec] may carry a `skipGate`; when it
/// returns a note the pass is recorded as a synthetic skipped action
/// (`skipped: true`, `filesChanged: []`, the note as `output`) and never
/// spawned. Only the `build` spec carries one (see
/// [BuildRelevance.refactorBuildSkipNote]) — `format` and `fix` are cheap
/// and always worth running.
///
/// The command (not this service) is responsible for the test-directory
/// immutability check and the overall `lib/` attribution check; this
/// service only records what each pass did.
library;

import 'dart:async';
import 'dart:io';

import '../../../commands/build_command.dart';
import '../../../cli/zfa_executable.dart';
import '../../../core/generation/tracked_generated_output_guard.dart';
import '../../../version.dart';
import '../models/refactor_action.dart';
import 'build_relevance.dart';
import 'step_runner.dart';
import 'tdd_timeout.dart';
import 'tree_snapshot.dart';

/// One invocation the registry asks the executor to run.
class RefactorPassInvocation {
  const RefactorPassInvocation({
    required this.passName,
    required this.command,
    required this.workingDirectory,
  });

  /// The pass name (`build`, `format`, `fix`).
  final String passName;

  /// The exact command line to execute (e.g. `dart format lib/`).
  final String command;

  /// The working directory the command runs in.
  final String workingDirectory;

  @override
  String toString() => 'RefactorPassInvocation($passName: $command)';
}

/// The outcome of a single process invocation, as recorded by the executor.
class ProcessRunOutcome {
  const ProcessRunOutcome({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.startedProcess,
    this.timedOut = false,
  });

  final String command;
  final int exitCode;
  final String output;
  final bool startedProcess;

  /// True when the pass process was killed by the per-command timeout
  /// (bug #742): the process launched but outlived the deadline.
  final bool timedOut;
}

/// Injectable process executor. The default implementation runs each pass
/// under a hard deadline ([DefaultProcessExecutor], bug #742); tests pass a
/// fake that records invocations and returns programmed outcomes.
abstract interface class ProcessExecutor {
  Future<ProcessRunOutcome> run(RefactorPassInvocation invocation);
}

/// The default [ProcessExecutor] — runs the command under a hard deadline
/// (bug #742): a pass that outlives [timeout] is killed (SIGKILL) and
/// recorded as a timed-out failure so the registry misfire-stops instead of
/// hanging forever. Defaults to [TddTimeouts.defaultRefactorPass].
class DefaultProcessExecutor implements ProcessExecutor {
  const DefaultProcessExecutor({this.timeout, this.environment});

  /// The per-pass deadline; `null` uses [TddTimeouts.defaultRefactorPass].
  final Duration? timeout;

  /// The caller's per-run scratch environment (spec 1520) — MERGED into
  /// each pass child's inherited environment, so a pass that spawns `dart`
  /// (build, `dart format`, `dart fix`) writes its caches inside the run's
  /// scratch. Null inherits the parent environment unchanged.
  final Map<String, String>? environment;

  @override
  Future<ProcessRunOutcome> run(RefactorPassInvocation inv) async {
    final tokens = _tokenize(inv.command);
    if (tokens.isEmpty) {
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: -1,
        output: 'empty command for pass ${inv.passName}',
        startedProcess: false,
      );
    }
    final executable = tokens.first;
    final args = tokens.skip(1).toList();
    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: inv.workingDirectory,
        timeout: timeout ?? TddTimeouts.defaultRefactorPass,
        environment: environment,
      );
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: result.exitCode,
        output: '${result.stdout}${result.stderr}'.trim(),
        startedProcess: true,
      );
    } on ProcessTimeoutException catch (e) {
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: -1,
        output: e.toString(),
        startedProcess: true,
        timedOut: true,
      );
    } on ProcessException catch (e) {
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: -1,
        output: 'Failed to start "$executable": $e',
        startedProcess: false,
      );
    }
  }

  /// Tokenize a command line into an executable + argument list. Quote
  /// pairs wrapping a token are stripped (shell quoting, not data). The
  /// splitter is quote-aware so a quoted path containing spaces (e.g. a
  /// resolved zfa entrypoint under "C:\Program Files\..." or "/home/my
  /// tools/bin/zfa") survives as ONE token (bug #689 follow-up:
  /// resolved absolute paths must execute verbatim).
  static List<String> _tokenize(String command) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    String? quote;
    for (var i = 0; i < command.length; i++) {
      final c = command[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else {
          buffer.write(c);
        }
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        continue;
      }
      if (c == ' ' || c == '\t') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(c);
    }
    if (quote != null) {
      // Unbalanced quote: keep the raw remainder rather than dropping it.
      buffer.write(quote);
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }
}

/// One pass spec: name, command, and the executor invocation.
class RefactorPassSpec {
  const RefactorPassSpec({
    required this.name,
    required this.command,
    this.skipGate,
  });

  final String name;
  final String command;

  /// Issue #1624: an optional scheduling gate. A non-null result is a
  /// skip note — the pass is recorded as a synthetic skipped action
  /// (`skipped: true`, `filesChanged: []`) and never spawned; null runs
  /// the pass. Only the `build` spec carries one:
  /// [RefactorPasses.defaultPassSpecs] attaches
  /// [BuildRelevance.refactorBuildSkipNote] when the registry was
  /// constructed with a project root.
  final Future<String?> Function()? skipGate;
}

/// The result of running the full pass registry.
class RefactorPassesResult {
  RefactorPassesResult({
    required this.actions,
    required this.stopped,
    required this.failedPass,
    this.refusalReason,
  });

  /// Every recorded action, in registry order. Includes the failing pass
  /// when [stopped] is true.
  final List<RefactorAction> actions;

  /// True when the registry stopped early because a pass failed (non-zero
  /// exit or process did not start) — or because it REFUSED to continue:
  /// the build pass deleted a git-tracked generated-name file whose
  /// restoration was impossible (spec 1540 restore-or-refuse), and
  /// re-proving a broken tree would be dishonest evidence.
  final bool stopped;

  /// The name of the pass that failed and stopped the registry, or null
  /// when all passes completed.
  final String? failedPass;

  /// Spec 1540: when the registry refused to continue after a pass deleted
  /// a git-tracked generated-name file that could not be restored, this
  /// carries the refusal + the exact manual restore remedy. Null on every
  /// other code path (plain failures keep their exit-code semantics).
  final String? refusalReason;

  /// True when every pass completed successfully (no stop, no failure).
  bool get completed => !stopped;
}

/// The fixed pass registry + executor.
class RefactorPasses {
  RefactorPasses(
    this.projectRoot, {
    ProcessExecutor? executor,
    Future<List<RefactorPassSpec>>? passSpecs,
    String? zfaBinOverride,
    Map<String, String>? environment,
    Duration? passTimeout,
    this.warningsBlocking = false,
    ZfaEnsureCompiled? ensureCompiled,
    Future<String?> Function()? buildSkipGate,
  }) : _executor =
           executor ??
           DefaultProcessExecutor(
             timeout: passTimeout,
             environment: environment,
           ),
       _passSpecsFuture =
           passSpecs ??
           defaultPassSpecs(
             projectRoot: projectRoot,
             zfaBinOverride: zfaBinOverride,
             environment: environment,
             ensureCompiled: ensureCompiled,
             buildSkipGate: buildSkipGate,
           );

  /// Project root the passes operate on.
  final String projectRoot;

  /// Issue #1472 (SC-5): the TDD profile's `analyze-gate:` strictness —
  /// true restores the legacy warnings-blocking refusal for the build
  /// pass. Default is errors-only (fail-open to the fix).
  final bool warningsBlocking;

  final ProcessExecutor _executor;
  final Future<List<RefactorPassSpec>> _passSpecsFuture;

  /// The default fixed pass set: build → format → fix (spec 048 Decision 2).
  ///
  /// The build pass invokes the zfa entrypoint resolved through the same
  /// tiers make/gen/verify use (PipelineRunner FR-004 / U11 / StepRunner
  /// bug #690) — bug #689: the previous hardcoded `dart run bin/zfa.dart
  /// build` misfired with exit 255 in every project bootstrapped by
  /// `zfa setup`, which installs the system zfa and never creates
  /// `bin/zfa.dart`.
  ///
  /// [zfaBinOverride] (the `--zfa-bin` flag) wins when provided, mirroring
  /// tier 1. [environment] is the full platform environment handed to
  /// [StepRunner.resolveEntrypoint]; tests inject a fixture PATH, while
  /// production reads `Platform.environment` directly.
  ///
  /// Async because the build entrypoint search reads files; tests can
  /// inject a pre-resolved [RefactorPassSpec.list] via the [passSpecs]
  /// constructor parameter to avoid awaiting the resolution.
  ///
  /// [ensureCompiled] is the no-JIT seam handed to [zfaBuildCommand] —
  /// tests inject a fake so resolving a source entrypoint does not AOT
  /// compile the real package.
  ///
  /// Issue #1624: [projectRoot] binds the build pass's build-relevance
  /// gate ([BuildRelevance.refactorBuildSkipNote]); [buildSkipGate]
  /// replaces it outright for tests. Only the `build` spec carries a
  /// gate — `format` and `fix` are cheap and always worth running.
  static Future<List<RefactorPassSpec>> defaultPassSpecs({
    String? projectRoot,
    String? zfaBinOverride,
    Map<String, String>? environment,
    ZfaEnsureCompiled? ensureCompiled,
    Future<String?> Function()? buildSkipGate,
  }) async {
    final buildCommand = await zfaBuildCommand(
      zfaBinOverride: zfaBinOverride,
      environment: environment,
      ensureCompiled: ensureCompiled,
    );
    // Issue #1624: the build pass is gated by build relevance. A caller
    // may inject its own gate; with none given, the real gate is bound to
    // [projectRoot]. A null root (the unit-test shape that only resolves a
    // command without a project tree) attaches no gate, so the pass runs
    // exactly as before.
    final gate =
        buildSkipGate ??
        (projectRoot == null
            ? null
            : () => BuildRelevance.refactorBuildSkipNote(
                projectRoot: projectRoot,
              ));
    return [
      RefactorPassSpec(name: 'build', command: buildCommand, skipGate: gate),
      const RefactorPassSpec(name: 'format', command: 'dart format lib/'),
      const RefactorPassSpec(name: 'fix', command: 'dart fix --apply lib/'),
    ];
  }

  /// The pass specs this registry will execute, in order.
  ///
  /// Async because the default spec list depends on
  /// [StepRunner.resolveEntrypoint], which performs file I/O checks.
  Future<List<RefactorPassSpec>> get passSpecs async =>
      List<RefactorPassSpec>.unmodifiable(await _passSpecsFuture);

  /// Run every pass in order, stopping at the first failure.
  ///
  /// For each pass:
  ///   0. (Issue #1624) Ask the spec's `skipGate`, when it has one: a
  ///      non-null note records a synthetic skipped action and continues
  ///      to the next spec — no snapshot, no tracked guard, no spawn.
  ///   1. Capture a before snapshot of `lib/`.
  ///   2. Invoke the executor with the pass's command.
  ///   3. Capture an after snapshot of `lib/`.
  ///   4. Compute `filesChanged` from the symmetric diff.
  ///   5. Record the [RefactorAction].
  ///   6. On non-zero exit or `startedProcess: false`, stop remaining passes.
  ///
  /// Spec 1540 (restore-or-refuse): the `build` pass is additionally
  /// bracketed by a git-tracked generated-name snapshot/restore — a build
  /// that deletes a hand-authored placeholder (issue #1540) gets it restored
  /// byte-identical BEFORE the after-snapshot (so the restoration never
  /// pollutes `filesChanged` or the attribution check), the restoration is
  /// recorded in the action's output as evidence, and an IMPOSSIBLE
  /// restoration stops the registry with [RefactorPassesResult.refusalReason]
  /// naming the exact `git checkout --` remedy instead of deleting-and-"passing".
  Future<RefactorPassesResult> run() async {
    final actions = <RefactorAction>[];
    final specs = await passSpecs;
    for (final spec in specs) {
      // Issue #1624: a gated pass that proves it has nothing to do is
      // recorded as a synthetic skipped action and never spawned. No
      // snapshot is captured and the #1540 tracked guard is not armed —
      // both only make sense around a process that actually ran.
      final skipNote = spec.skipGate == null ? null : await spec.skipGate!();
      if (skipNote != null) {
        actions.add(
          RefactorAction(
            name: spec.name,
            command: spec.command,
            exitCode: 0,
            filesChanged: const [],
            output: skipNote,
            skipped: true,
          ),
        );
        continue;
      }
      final before = await TreeSnapshot.capture(
        projectRoot,
        trees: const ['lib'],
      );
      // Spec 1540: only the build pass runs codegen whose cleanup can
      // orphan a hand-authored placeholder; format/fix never delete files.
      final trackedGuard = spec.name == 'build'
          ? TrackedGeneratedOutputGuard(projectRoot: projectRoot)
          : null;
      final trackedSnapshot = trackedGuard == null
          ? null
          : await trackedGuard.capture();
      final invocation = RefactorPassInvocation(
        passName: spec.name,
        command: spec.command,
        workingDirectory: projectRoot,
      );
      final outcome = await _executor.run(invocation);

      // Spec 1540: restore before the after-snapshot so a successful
      // restoration is invisible to the diff (byte-identical to `before`)
      // and visible only in the recorded evidence.
      var passOutput = outcome.output;
      String? refusalReason;
      if (trackedGuard != null && trackedSnapshot != null) {
        final deleted = trackedGuard.detectDeleted(trackedSnapshot);
        if (deleted.isNotEmpty) {
          final restore = await trackedGuard.restore(trackedSnapshot, deleted);
          if (restore.restored.isNotEmpty) {
            passOutput = passOutput.isEmpty
                ? '[1540] restored ${restore.restored.length} git-tracked '
                      'generated-name file(s) deleted by the build pass: '
                      '${restore.restored.join(', ')}'
                : '$passOutput\n[1540] restored ${restore.restored.length} '
                      'git-tracked generated-name file(s) deleted by the build '
                      'pass: ${restore.restored.join(', ')}';
          }
          if (restore.failed.isNotEmpty) {
            final remedy = TrackedGeneratedOutputGuard.restoreRemedyLines(
              restore.failed,
            ).join('\n');
            refusalReason =
                '[1540] refused: the build pass deleted git-tracked '
                'generated-name file(s) it could not restore '
                '(${restore.failed.join(', ')}).\n$remedy';
            // The unrestorable deletion is part of the pass's net effect.
            passOutput = passOutput.isEmpty
                ? refusalReason
                : '$passOutput\n$refusalReason';
          }
        }
      }

      final after = await TreeSnapshot.capture(
        projectRoot,
        trees: const ['lib'],
      );
      final filesChanged = before
          .changedPaths(after)
          .where((path) => path.startsWith('lib/'))
          .toList();
      actions.add(
        RefactorAction(
          name: spec.name,
          command: spec.command,
          exitCode: outcome.exitCode,
          filesChanged: filesChanged,
          output: passOutput,
          timedOut: outcome.timedOut,
        ),
      );
      // Spec 1540 restore-or-refuse: an unrestorable tracked deletion
      // refuses the registry (misfire-stop on `build`) with the remedy —
      // never a silent delete-and-continue on a broken tree.
      if (refusalReason != null) {
        return RefactorPassesResult(
          actions: actions,
          stopped: true,
          failedPass: spec.name,
          refusalReason: refusalReason,
        );
      }
      // Misfire-stop (FR-010): non-zero exit OR process did not start.
      // Issue #1472: ONE arm tolerates a failed build pass — the analyze
      // gate's own WARNINGS-ONLY refusal. The gate (issues #395/#1035)
      // refuses the tree on errors OR warnings; a hand-implemented subject
      // with one unused import then misfire-stopped the registry and the
      // `dart fix --apply` pass — the only pass that would remove exactly
      // that lint — never ran (deadlock). When the failed pass IS `build`,
      // the process ran to completion (no spawn failure, no #742 timeout),
      // and its output proves the refusal was the gate's own verdict with
      // 0 error(s) and >=1 warning(s) (cross-checked through the shared
      // `BuildCommand.countAnalyzerIssues` parser — the single #1035
      // line-format contract), the verdict is logged with its accurate
      // counts (warnings are the fix pass's input, not "did not compile
      // cleanly") and the registry CONTINUES to format → fix. The recorded
      // action keeps the true exit code and raw output. A build verdict
      // carrying analyzer errors, any non-gate failure class, a spawn
      // failure, or a timeout keeps the honest misfire-stop byte-
      // identically — and `warningsBlocking` (the TDD profile's
      // `analyze-gate: warnings-blocking`, issue #1407's opt-in) skips the
      // arm entirely, restoring the legacy refusal.
      if (outcome.exitCode != 0 || !outcome.startedProcess) {
        final toleratedWarningsOnlyRefusal =
            spec.name == 'build' &&
            !warningsBlocking &&
            outcome.startedProcess &&
            !outcome.timedOut &&
            BuildCommand.analyzeGateWarningsOnlyRefusal(outcome.output);
        if (toleratedWarningsOnlyRefusal) {
          BuildCommand.logAnalyzeGateRefusal(
            outcome.output,
            policy:
                'for the refactor build pass (issue #1472, errors-only '
                'gate)',
            next: 'the dart fix pass runs next.',
          );
          continue;
        }
        return RefactorPassesResult(
          actions: actions,
          stopped: true,
          failedPass: spec.name,
        );
      }
    }
    return RefactorPassesResult(
      actions: actions,
      stopped: false,
      failedPass: null,
    );
  }
}

/// Resolve the `build` pass command line (bug #689).
///
/// Delegates the entrypoint search to [StepRunner.resolveEntrypoint]
/// (the same tier-2-through-tier-6 chain bug #690 added for the TDD
/// step runner): `bin/zfa.dart` in the running CLI's tree, the package
/// path fallback, then a system `zfa` on PATH, then `Platform.script`,
/// then `Platform.resolvedExecutable`. The explicit `--zfa-bin`
/// override is honored first.
///
/// The returned path is shaped into a command line: a compiled binary is
/// invoked directly as `<path> build`. A `.dart` source is AOT compiled
/// first (`ZfaExecutable.ensureCompiled` — the no-JIT policy) and the
/// artifact is invoked directly; the `dart <path> build` shape survives
/// only under the `ZFA_ALLOW_JIT=1` escape hatch. Tokens that contain
/// spaces are quoted; the executor's quote-aware tokenizer keeps them as
/// single argv entries.
///
/// [environment] lets tests inject a fixture PATH; production callers
/// pass null and the chain reads `Platform.environment` itself.
/// [resolveDrivingEntrypoint] is the same kind of seam for the #1472 pin:
/// it replaces [StepRunner.resolveEntrypoint] as the source of the driving
/// CLI's own entrypoint, so tests can prove a fixture replacement instead
/// of spawning the real `bin/zfa.dart`. [ensureCompiled] is the no-JIT
/// compiler seam (defaults to [ZfaExecutable.ensureCompiled]); fast-tier
/// tests inject a fake so no real `dart compile exe` runs.
///
/// This is async because [StepRunner.resolveEntrypoint] performs file
/// I/O checks. The pass registry ([RefactorPasses.defaultPassSpecs]) is
/// async-aware: callers that need a synchronous spec list should use
/// [zfaBuildCommandSync] with a pre-resolved entrypoint.
Future<String> zfaBuildCommand({
  String? zfaBinOverride,
  Map<String, String>? environment,
  ZfaEntrypointResolver? resolveDrivingEntrypoint,
  ZfaEnsureCompiled? ensureCompiled,
}) async {
  String quoteIfNeeded(String token) =>
      token.contains(' ') || token.contains('\t') ? '"$token"' : token;

  final env = environment ?? Platform.environment;
  final compile = ensureCompiled ?? ZfaExecutable.ensureCompiled;

  // Tier 1 — explicit override (mirrors PipelineRunner / StepRunner tier 1).
  // No-JIT policy: a `.dart` override is compiled too, so `--zfa-bin` can
  // never leak a VM spawn.
  if (zfaBinOverride != null && zfaBinOverride.isNotEmpty) {
    final compiled = await compile(zfaBinOverride, environment: env);
    return '${quoteIfNeeded(compiled)} build';
  }

  // Tiers 2+ — delegate to the canonical chain. Tests inject a fixture
  // environment; production uses the live platform.
  //
  // Bug #717: the canonical chain's package-config tier resolves the
  // RUNNING package tree's own `bin/zfa.dart` (reachable only in
  // source/test/kernel contexts, never from a compiled system binary)
  // and thereby shadowed the system zfa on PATH. `zfa setup` installs
  // the system CLI and never creates `bin/zfa.dart` in the target
  // project, so the build pass calls the system zfa directly (Option
  // B, issue #717). Suppressing the package tier leaves this pass the
  // documented order: `--zfa-bin` override → running-from-source →
  // `zfa` on PATH → dart+script fallbacks. `make` / `gen` / `verify-red`
  // / `tdd run` keep the shared chain unchanged.
  String entrypoint;
  try {
    entrypoint = await StepRunner.resolveEntrypoint(
      script: Platform.script,
      resolvedExecutable: Platform.resolvedExecutable,
      environment: env,
      resolvePackageUri: (_) async => null,
    );
  } on StateError {
    // Genuinely unresolvable: keep the bare-name fallback so the
    // executor records the misfire honestly (FR-010) instead of
    // crashing the refactor command.
    return 'zfa build';
  }

  // No-JIT policy: compile BEFORE the #1472 probe, so both sides of the
  // version comparison are compiled binaries (the probe of a source
  // entrypoint would itself be a JIT spawn).
  entrypoint = await compile(entrypoint, environment: env);

  // Issue #1472: pin the build pass to the zfa version driving this run.
  entrypoint = await _pinToDrivingVersion(
    entrypoint,
    env,
    resolveDrivingEntrypoint: resolveDrivingEntrypoint,
    ensureCompiled: ensureCompiled,
  );

  final argv = ZfaExecutable.commandFor(entrypoint, const [
    'build',
  ], environment: env);
  return argv.map(quoteIfNeeded).join(' ');
}

/// The entrypoint resolver the pin uses for the driving CLI's own tree —
/// [StepRunner.resolveEntrypoint]'s shape, so the pin's tests can inject a
/// fixture instead of resolving (and probing) the real `bin/zfa.dart`,
/// whose cold JIT compile outlives the probe's [TddTimeouts.defaultProbe]
/// bound and would therefore read as unprovable.
typedef ZfaEntrypointResolver =
    Future<String> Function({
      required Uri script,
      required String resolvedExecutable,
      required Map<String, String> environment,
      Future<Uri?> Function(Uri packageUri)? resolvePackageUri,
    });

/// Issue #1472: the `--version` output line of a zfa entrypoint —
/// `zfa v<semver>` (the single writer is the CliRunner version command).
final RegExp _zfaVersionLinePattern = RegExp(r'^zfa v(\S+)', multiLine: true);

/// Probe [entrypoint]'s `--version` and return the parsed version string,
/// or null when UNPROVABLE: the spawn fails, the process exits non-zero,
/// prints nothing, or prints no `zfa v<semver>` line. Silence rules per
/// issue #1184's model — an advisory/pinning check must never break the
/// invocation and must never act on unprovable input, so every failure
/// mode degrades to null and the caller keeps the current resolution.
/// [entrypoint] is expected to be compiled (the caller resolves through
/// `ZfaExecutable.ensureCompiled` first); the argv is still shaped through
/// `ZfaExecutable.commandFor`, so a source entrypoint either rides the
/// `ZFA_ALLOW_JIT=1` escape hatch or reads as unprovable rather than
/// spawning the VM behind the policy's back. Bounded by
/// [TddTimeouts.defaultProbe] so a hung candidate cannot stall the
/// refactor.
Future<String?> _probeZfaVersion(
  String entrypoint,
  Map<String, String> environment,
) async {
  try {
    final command = ZfaExecutable.commandFor(entrypoint, const [
      '--version',
    ], environment: environment);
    final result = await runTimed(
      command.first,
      command.sublist(1),
      timeout: TddTimeouts.defaultProbe,
    );
    if (result.exitCode != 0) return null;
    final stdoutText = (result.stdout as String? ?? '').trim();
    if (stdoutText.isEmpty) return null;
    final match = _zfaVersionLinePattern.firstMatch(stdoutText);
    if (match == null) return null;
    return match.group(1);
  } catch (_) {
    // ProcessException (not executable / missing), ProcessTimeoutException
    // (hung candidate), a StateError from the no-JIT gate, anything else —
    // unprovable, never fatal.
    return null;
  }
}

/// Issue #1472: pin the build pass to the zfa version driving the run.
///
/// The #717 chain above prefers the system zfa on PATH whenever the
/// running-from-source tiers fail to resolve (e.g. the global `-C` chdir
/// re-anchoring `Platform.script`, issue #1371). A stale system install
/// then executes the build pass with a DIFFERENT gate than the CLI
/// driving the run. Probe the candidate: a provably different version
/// re-resolves through the UNSUPPRESSED chain (the real package tier) and
/// replaces it — but only on proof. BOTH sides of the swap are probed:
/// the candidate must provably disagree, AND the replacement must
/// provably carry the driving version. An equal or unprovable candidate
/// keeps the #717 resolution byte-identically, and an equal, unprovable,
/// or unresolvable (StateError) replacement does too — the silence rule
/// (#1184) guards the swap in both directions, so a stale or foreign tree
/// can never be pinned silently. The honest pin line prints only on the
/// proven path.
///
/// [resolveDrivingEntrypoint] is the test seam: production resolves
/// through [StepRunner.resolveEntrypoint]; the pin's tests inject a
/// fixture entrypoint so the real `bin/zfa.dart` (whose cold JIT compile
/// outlives the probe bound) never has to be spawned. [ensureCompiled] is
/// the matching no-JIT seam for the replacement the resolver returns — a
/// resolved `bin/zfa.dart` is compiled before it is probed, so neither
/// side of the swap can be a JIT spawn. A replacement that cannot be
/// compiled is unprovable, exactly like an unresolvable one: the #717
/// candidate is kept rather than crashing the refactor.
Future<String> _pinToDrivingVersion(
  String entrypoint,
  Map<String, String> env, {
  ZfaEntrypointResolver? resolveDrivingEntrypoint,
  ZfaEnsureCompiled? ensureCompiled,
}) async {
  final candidateVersion = await _probeZfaVersion(entrypoint, env);
  if (candidateVersion == null || candidateVersion == version) {
    return entrypoint;
  }
  final resolve = resolveDrivingEntrypoint ?? StepRunner.resolveEntrypoint;
  try {
    final resolvedDriving = await resolve(
      script: Platform.script,
      resolvedExecutable: Platform.resolvedExecutable,
      environment: env,
    );
    final driving = await (ensureCompiled ?? ZfaExecutable.ensureCompiled)(
      resolvedDriving,
      environment: env,
    );
    if (driving == entrypoint) return entrypoint;
    // The replacement is proven too: a different tree (a path-override
    // sibling checkout, a snapshot built from an older tree, a
    // `-C`-anchored launch) must never be pinned on the strength of the
    // candidate's disagreement alone.
    final drivingVersion = await _probeZfaVersion(driving, env);
    if (drivingVersion != version) return entrypoint;
    print(
      '   build pass: resolved build zfa is v$candidateVersion — pinned to '
      'the driving CLI v$version (issue #1472).',
    );
    return driving;
  } on StateError {
    // The driving entrypoint cannot be resolved — keep the #717
    // candidate (fail-open to current behavior, never crash).
    return entrypoint;
  } on ZfaCompilationException {
    // The driving entrypoint resolved to a source tree that cannot be
    // compiled. That is unprovable input, not a JIT justification: keep
    // the #717 candidate rather than spawning a VM child.
    return entrypoint;
  }
}

/// Build the command line for a pre-resolved entrypoint (bug #689).
///
/// Useful when the entrypoint has already been resolved (e.g. by an
/// earlier `await zfaBuildCommand`) and the caller only needs the
/// shape step. Synchronous; does no I/O.
///
/// No-JIT policy: [entrypoint] is expected to be compiled already (it must
/// have come out of `zfaBuildCommand`). A `.dart` entrypoint is only
/// accepted under the `ZFA_ALLOW_JIT=1` escape hatch; otherwise
/// `ZfaExecutable.commandFor` throws, loudly, instead of shaping a VM
/// command.
String zfaBuildCommandSync({
  required String entrypoint,
  Map<String, String>? environment,
}) {
  String quoteIfNeeded(String token) =>
      token.contains(' ') || token.contains('\t') ? '"$token"' : token;
  final argv = ZfaExecutable.commandFor(entrypoint, const [
    'build',
  ], environment: environment);
  return argv.map(quoteIfNeeded).join(' ');
}
