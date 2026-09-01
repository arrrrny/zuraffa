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
/// (spec 048 FR-010 — misfire-stop).
///
/// The command (not this service) is responsible for the test-directory
/// immutability check and the overall `lib/` attribution check; this
/// service only records what each pass did.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/refactor_action.dart';
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
  });

  final String command;
  final int exitCode;
  final String output;
  final bool startedProcess;
}

/// Injectable process executor. The default implementation uses
/// [Process.run]; tests pass a fake that records invocations and returns
/// programmed outcomes.
abstract interface class ProcessExecutor {
  Future<ProcessRunOutcome> run(RefactorPassInvocation invocation);
}

/// The default [ProcessExecutor] — runs the command via [Process.run].
class DefaultProcessExecutor implements ProcessExecutor {
  const DefaultProcessExecutor();

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
      final result = await Process.run(
        executable,
        args,
        workingDirectory: inv.workingDirectory,
      );
      return ProcessRunOutcome(
        command: inv.command,
        exitCode: result.exitCode,
        output: '${result.stdout}${result.stderr}'.trim(),
        startedProcess: true,
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
    List<RefactorPassSpec>? passSpecs,
    String? zfaBinOverride,
    String? pathEnv,
  }) : _executor = executor ?? const DefaultProcessExecutor(),
       _passSpecs =
           passSpecs ??
           defaultPassSpecs(zfaBinOverride: zfaBinOverride, pathEnv: pathEnv);

  /// Project root the passes operate on.
  final String projectRoot;

  final ProcessExecutor _executor;
  final List<RefactorPassSpec> _passSpecs;

  /// The default fixed pass set: build → format → fix (spec 048 Decision 2).
  ///
  /// The build pass invokes the zfa entrypoint resolved through the same
  /// tiers make/gen/verify use (PipelineRunner FR-004 / U11) — bug #689:
  /// the previous hardcoded `dart run bin/zfa.dart build` misfired with
  /// exit 255 in every project bootstrapped by `zfa setup`, which installs
  /// the system zfa and never creates `bin/zfa.dart`.
  ///
  /// [zfaBinOverride] (the `--zfa-bin` flag) wins when provided, mirroring
  /// PipelineRunner tier 1. [pathEnv] overrides the PATH scanned for a
  /// system-installed `zfa` (tests inject a fixture bin dir; production
  /// reads Platform.environment).
  static List<RefactorPassSpec> defaultPassSpecs({
    String? zfaBinOverride,
    String? pathEnv,
  }) {
    return [
      RefactorPassSpec(
        name: 'build',
        command: zfaBuildCommand(
          zfaBinOverride: zfaBinOverride,
          pathEnv: pathEnv,
        ),
      ),
      const RefactorPassSpec(name: 'format', command: 'dart format lib/'),
      const RefactorPassSpec(name: 'fix', command: 'dart fix --apply lib/'),
    ];
  }

  /// The pass specs this registry will execute, in order.
  List<RefactorPassSpec> get passSpecs =>
      List<RefactorPassSpec>.unmodifiable(_passSpecs);

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
    for (final spec in _passSpecs) {
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
        ),
      );
      // Misfire-stop (FR-010): non-zero exit OR process did not start.
      if (outcome.exitCode != 0 || !outcome.startedProcess) {
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
/// Mirrors the PipelineRunner entrypoint tiers (FR-004 / U11 — the same
/// resolution make/gen/verify use), so `zfa tdd refactor` invokes the SAME
/// zfa binary the user ran:
///
///   1. [zfaBinOverride] (the `--zfa-bin` flag) when set.
///   2. The running CLI from source: Platform.script basename
///      `zfa.dart`/`zuraffa.dart` → `<dart> <script> build`.
///   3. A system-installed `zfa` on PATH (issue scenario:
///      `~/.local/bin/zfa`) → `<zfa> build`.
///   4. Fallback: `<dart> <Platform.script> build` (compiled snapshot /
///      global-activate shapes).
///
/// Tokens that contain spaces are emitted quoted; the executor's
/// quote-aware tokenizer keeps them as single argv entries.
String zfaBuildCommand({String? zfaBinOverride, String? pathEnv}) {
  String quoteIfNeeded(String token) =>
      token.contains(' ') || token.contains('\t') ? '"$token"' : token;

  // 1. Explicit override (tier 1).
  if (zfaBinOverride != null && zfaBinOverride.isNotEmpty) {
    return '${quoteIfNeeded(zfaBinOverride)} build';
  }

  final script = Platform.script;
  final scriptPath = script.scheme == 'file' ? script.toFilePath() : null;
  final scriptBase = scriptPath?.split(Platform.pathSeparator).last;

  // 2. Running CLI from source (tier 2).
  if (scriptBase == 'zfa.dart' || scriptBase == 'zuraffa.dart') {
    return '${quoteIfNeeded(Platform.resolvedExecutable)} '
        '${quoteIfNeeded(scriptPath!)} build';
  }

  // 3. System-installed zfa on PATH (tier 3).
  final path = pathEnv ?? Platform.environment['PATH'];
  if (path != null && path.isNotEmpty) {
    final extensions = Platform.isWindows
        ? (Platform.environment['PATHEXT'] ?? '.EXE;.BAT;.CMD')
              .split(';')
              .where((extension) => extension.isNotEmpty)
        : const [''];
    for (final directory in path.split(Platform.isWindows ? ';' : ':')) {
      if (directory.isEmpty) continue;
      for (final extension in extensions) {
        final candidate = File(p.join(directory, 'zfa$extension'));
        if (!candidate.existsSync()) continue;
        if (Platform.isWindows || (candidate.statSync().mode & 0x49) != 0) {
          return '${quoteIfNeeded(candidate.path)} build';
        }
      }
    }
  }

  // 4. Fallback (tier 4): dart + the running script.
  if (scriptPath != null) {
    return '${quoteIfNeeded(Platform.resolvedExecutable)} '
        '${quoteIfNeeded(scriptPath)} build';
  }

  // Last resort: bare name — the executor records the failure honestly
  // if this shape cannot run (misfire-stop, FR-010).
  return 'zfa build';
}
