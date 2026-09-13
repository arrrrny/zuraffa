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
///      fallback.
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
/// The command (not this service) is responsible for the test-directory
/// immutability check and the overall `lib/` attribution check; this
/// service only records what each pass did.
library;

import 'dart:async';
import 'dart:io';

import '../../../commands/build_command.dart';
import '../../../version.dart';
import '../models/refactor_action.dart';
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
  const DefaultProcessExecutor({this.timeout});

  /// The per-pass deadline; `null` uses [TddTimeouts.defaultRefactorPass].
  final Duration? timeout;

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
  const RefactorPassSpec({required this.name, required this.command});

  final String name;
  final String command;
}

/// The result of running the full pass registry.
class RefactorPassesResult {
  RefactorPassesResult({
    required this.actions,
    required this.stopped,
    required this.failedPass,
  });

  /// Every recorded action, in registry order. Includes the failing pass
  /// when [stopped] is true.
  final List<RefactorAction> actions;

  /// True when the registry stopped early because a pass failed (non-zero
  /// exit or process did not start).
  final bool stopped;

  /// The name of the pass that failed and stopped the registry, or null
  /// when all passes completed.
  final String? failedPass;

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
  }) : _executor = executor ?? DefaultProcessExecutor(timeout: passTimeout),
       _passSpecsFuture =
           passSpecs ??
           defaultPassSpecs(
             zfaBinOverride: zfaBinOverride,
             environment: environment,
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
  static Future<List<RefactorPassSpec>> defaultPassSpecs({
    String? zfaBinOverride,
    Map<String, String>? environment,
  }) async {
    final buildCommand = await zfaBuildCommand(
      zfaBinOverride: zfaBinOverride,
      environment: environment,
    );
    return [
      RefactorPassSpec(name: 'build', command: buildCommand),
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
  ///   1. Capture a before snapshot of `lib/`.
  ///   2. Invoke the executor with the pass's command.
  ///   3. Capture an after snapshot of `lib/`.
  ///   4. Compute `filesChanged` from the symmetric diff.
  ///   5. Record the [RefactorAction].
  ///   6. On non-zero exit or `startedProcess: false`, stop remaining passes.
  Future<RefactorPassesResult> run() async {
    final actions = <RefactorAction>[];
    final specs = await passSpecs;
    for (final spec in specs) {
      final before = await TreeSnapshot.capture(
        projectRoot,
        trees: const ['lib'],
      );
      final invocation = RefactorPassInvocation(
        passName: spec.name,
        command: spec.command,
        workingDirectory: projectRoot,
      );
      final outcome = await _executor.run(invocation);
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
          output: outcome.output,
          timedOut: outcome.timedOut,
        ),
      );
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
            _isWarningsOnlyBuildGateRefusal(outcome.output);
        if (toleratedWarningsOnlyRefusal) {
          _logWarningsOnlyGateRefusal(outcome.output);
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

  /// The build command's analyze-gate refusal verdict (issue #1472). The
  /// message has exactly ONE writer — the build command's post-build
  /// analyze gate (issues #395/#1035):
  /// `❌ dart analyze reported <E> error(s) and <W> warning(s) — generated
  /// code does not compile cleanly.` — and carries the counts the gate
  /// decided on. The same machine contract the make's errors-only gate
  /// reads (issue #1407); the two interpretations can never drift apart
  /// because both read this one line.
  static final RegExp _analyzeGateRefusalPattern = RegExp(
    r'dart analyze reported (\d+) error\(s\) and (\d+) warning\(s\)',
  );

  /// Issue #1472: whether [buildOutput] is the build command's
  /// analyze-gate refusal on WARNINGS ONLY — 0 error(s) and at least one
  /// warning — i.e. the tree compiles (0 errors) and the build pass
  /// failed only because the #1035 gate treats warnings as fatal.
  ///
  /// Requires BOTH of:
  ///
  ///   - the gate's own refusal message naming 0 errors (the single
  ///     writer documented on [_analyzeGateRefusalPattern]). A build
  ///     failure without that message is some other failure class
  ///     (build_runner, DDA routes, post-build verifiers) and keeps the
  ///     misfire-stop unchanged;
  ///   - the shared analyzer line-format parser
  ///     ([BuildCommand.countAnalyzerIssues], the #1035 single contract)
  ///     finds NO `error -` lines in the raw output. If the gate message
  ///     and the parser disagree, the honest misfire-stop stands
  ///     (safe-failure, never a silent pass).
  static bool _isWarningsOnlyBuildGateRefusal(String buildOutput) {
    final match = _analyzeGateRefusalPattern.firstMatch(buildOutput);
    if (match == null) return false;
    final errors = int.tryParse(match.group(1)!) ?? -1;
    final warnings = int.tryParse(match.group(2)!) ?? -1;
    if (errors != 0 || warnings < 1) return false;
    return !BuildCommand.analyzeReportsError(buildOutput);
  }

  /// Issue #1472 (SC-3): log the tolerated warnings-only gate refusal —
  /// the verdict naming the accurate counts (0 error(s), N warning(s) —
  /// warnings are the dart fix pass's input, NOT a compile failure), then
  /// the analyzer `warning -` lines themselves. A voluminous verdict logs
  /// a capped sample plus a remainder count so the transcript stays
  /// readable.
  static void _logWarningsOnlyGateRefusal(String buildOutput) {
    final match = _analyzeGateRefusalPattern.firstMatch(buildOutput)!;
    final warnings = int.parse(match.group(2)!);
    print(
      '   analyze gate: 0 error(s), $warnings warning(s) — warnings are '
      'non-blocking for the refactor build pass (issue #1472, errors-only '
      'gate): the dart fix pass runs next.',
    );
    final warningLines = RegExp(
      r'^\s*warning\s*-\s.*$',
      multiLine: true,
    ).allMatches(buildOutput).map((m) => m.group(0)!.trim()).toList();
    const maxLogged = 10;
    for (final line in warningLines.take(maxLogged)) {
      print('   $line');
    }
    final remainder = warningLines.length - maxLogged;
    if (remainder > 0) {
      print('   ... $remainder more warning(s)');
    }
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
/// The returned path is shaped into a command line: a `.dart` source is
/// run with `dart <path> build`; a compiled binary is invoked directly
/// as `<path> build`. Tokens that contain spaces are quoted; the
/// executor's quote-aware tokenizer keeps them as single argv entries.
///
/// [environment] lets tests inject a fixture PATH; production callers
/// pass null and the chain reads `Platform.environment` itself.
/// Resolve the `build` pass command line (bug #689).
///
/// Delegates the entrypoint search to [StepRunner.resolveEntrypoint]
/// (the same tier-2-through-tier-6 chain bug #690 added for the TDD
/// step runner): `bin/zfa.dart` in the running CLI's tree, the package
/// path fallback, then a system `zfa` on PATH, then `Platform.script`,
/// then `Platform.resolvedExecutable`. The explicit `--zfa-bin`
/// override is honored first.
///
/// The returned path is shaped into a command line: a `.dart` source is
/// run with `dart <path> build`; a compiled binary is invoked directly
/// as `<path> build`. Tokens that contain spaces are quoted; the
/// executor's quote-aware tokenizer keeps them as single argv entries.
///
/// [environment] lets tests inject a fixture PATH; production callers
/// pass null and the chain reads `Platform.environment` itself.
///
/// This is async because [StepRunner.resolveEntrypoint] performs file
/// I/O checks. The pass registry ([RefactorPasses.defaultPassSpecs]) is
/// async-aware: callers that need a synchronous spec list should use
/// [zfaBuildCommandSync] with a pre-resolved entrypoint.
Future<String> zfaBuildCommand({
  String? zfaBinOverride,
  Map<String, String>? environment,
}) async {
  String quoteIfNeeded(String token) =>
      token.contains(' ') || token.contains('\t') ? '"$token"' : token;

  // Tier 1 — explicit override (mirrors PipelineRunner / StepRunner tier 1).
  if (zfaBinOverride != null && zfaBinOverride.isNotEmpty) {
    return '${quoteIfNeeded(zfaBinOverride)} build';
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
  final env = environment ?? Platform.environment;
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

  // Issue #1472: pin the build pass to the zfa version driving this run.
  entrypoint = await _pinToDrivingVersion(entrypoint, env);

  if (entrypoint.endsWith('.dart')) {
    return '${quoteIfNeeded(Platform.resolvedExecutable)} '
        '${quoteIfNeeded(entrypoint)} build';
  }
  return '${quoteIfNeeded(entrypoint)} build';
}

/// Issue #1472: the `--version` output line of a zfa entrypoint —
/// `zfa v<semver>` (the single writer is the CliRunner version command).
final RegExp _zfaVersionLinePattern = RegExp(r'^zfa v(\S+)', multiLine: true);

/// Probe [entrypoint]'s `--version` and return the parsed version string,
/// or null when UNPROVABLE: the spawn fails, the process exits non-zero,
/// prints nothing, or prints no `zfa v<semver>` line. Silence rules per
/// issue #1184's model — an advisory/pinning check must never break the
/// invocation and must never act on unprovable input, so every failure
/// mode degrades to null and the caller keeps the current resolution.
/// A `.dart` entrypoint runs through the current VM (`dart <path>
/// --version`); a compiled binary runs directly. Bounded by
/// [TddTimeouts.defaultProbe] so a hung candidate cannot stall the
/// refactor.
Future<String?> _probeZfaVersion(String entrypoint) async {
  try {
    final result = entrypoint.endsWith('.dart')
        ? await runTimed(Platform.resolvedExecutable, [
            entrypoint,
            '--version',
          ], timeout: TddTimeouts.defaultProbe)
        : await runTimed(entrypoint, const [
            '--version',
          ], timeout: TddTimeouts.defaultProbe);
    if (result.exitCode != 0) return null;
    final stdoutText = (result.stdout as String? ?? '').trim();
    if (stdoutText.isEmpty) return null;
    final match = _zfaVersionLinePattern.firstMatch(stdoutText);
    if (match == null) return null;
    return match.group(1);
  } catch (_) {
    // ProcessException (not executable / missing), ProcessTimeoutException
    // (hung candidate), anything else — unprovable, never fatal.
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
/// re-resolves through the UNSUPPRESSED chain (the real package tier) —
/// the driving CLI's own entrypoint, whose version is by definition the
/// driving version — and logs one honest line. An equal or unprovable
/// version keeps the #717 resolution byte-identically, and an
/// unresolvable driving entrypoint (StateError) fails open to the #717
/// candidate rather than crashing the refactor.
Future<String> _pinToDrivingVersion(
  String entrypoint,
  Map<String, String> env,
) async {
  final candidateVersion = await _probeZfaVersion(entrypoint);
  if (candidateVersion == null || candidateVersion == version) {
    return entrypoint;
  }
  try {
    final driving = await StepRunner.resolveEntrypoint(
      script: Platform.script,
      resolvedExecutable: Platform.resolvedExecutable,
      environment: env,
    );
    if (driving == entrypoint) return entrypoint;
    print(
      '   build pass: system zfa on PATH is v$candidateVersion — pinned to '
      'the driving CLI v$version (issue #1472).',
    );
    return driving;
  } on StateError {
    // The driving entrypoint cannot be resolved — keep the #717
    // candidate (fail-open to current behavior, never crash).
    return entrypoint;
  }
}

/// Build the command line for a pre-resolved entrypoint (bug #689).
///
/// Useful when the entrypoint has already been resolved (e.g. by an
/// earlier `await zfaBuildCommand`) and the caller only needs the
/// shape step. Synchronous; does no I/O.
String zfaBuildCommandSync({required String entrypoint}) {
  String quoteIfNeeded(String token) =>
      token.contains(' ') || token.contains('\t') ? '"$token"' : token;
  if (entrypoint.endsWith('.dart')) {
    return '${quoteIfNeeded(Platform.resolvedExecutable)} '
        '${quoteIfNeeded(entrypoint)} build';
  }
  return '${quoteIfNeeded(entrypoint)} build';
}
