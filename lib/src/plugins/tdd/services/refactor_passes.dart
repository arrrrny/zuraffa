/// `RefactorPasses` — the fixed pass registry + executor for
/// `zfa tdd refactor` (spec 048-tdd-refactor, T006; behaviors U1-U5).
///
/// The registry is a small, deliberately fixed set of idempotent
/// tool-driven normalization passes, executed in order:
///
///   1. `build`  — the resolved zfa CLI's `build` subcommand (codegen
///      normalization; bug #689 — resolves the entrypoint exactly like
///      `zfa tdd make` does via the shared zfa entrypoint resolver, with
///      `zfa build` as the static fallback spec)
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

import '../models/refactor_action.dart';
import 'tree_snapshot.dart';
import 'zfa_entrypoint.dart';

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
  /// pairs wrapping a token are stripped (shell quoting, not data).
  static List<String> _tokenize(String command) {
    final rawTokens = command.trim().split(RegExp(r'\s+'));
    return rawTokens.map((token) {
      var out = token;
      if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
        out = out.substring(1, out.length - 1);
      } else if (out.length >= 2 && out.startsWith("'") && out.endsWith("'")) {
        out = out.substring(1, out.length - 1);
      }
      return out;
    }).toList();
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
  }) : _executor = executor ?? const DefaultProcessExecutor(),
       _explicitPassSpecs = passSpecs;

  /// Project root the passes operate on.
  final String projectRoot;

  final ProcessExecutor _executor;

  /// Explicit specs injected by the caller (tests); when null the build
  /// pass resolves the zfa entrypoint at run() time (bug #689).
  final List<RefactorPassSpec>? _explicitPassSpecs;

  /// The default fixed pass set: build → format → fix (spec 048 Decision 2).
  ///
  /// The build pass invokes the system-installed `zfa` CLI (bug #689):
  /// `zfa setup` installs the zfa executable on PATH but never creates a
  /// project-local `bin/zfa.dart`, so the previous hardcoded
  /// `dart run bin/zfa.dart build` failed on every freshly bootstrapped
  /// project. When the default specs are used at run() time, the command
  /// is resolved through the shared zfa entrypoint resolver (the same
  /// resolution `zfa tdd make` uses), so running from a source checkout
  /// still prefers the checkout's CLI. These static specs remain the
  /// documented fallback and the evidence-stable default when resolution
  /// is unavailable.
  static const defaultPassSpecs = [
    RefactorPassSpec(name: 'build', command: 'zfa build'),
    RefactorPassSpec(name: 'format', command: 'dart format lib/'),
    RefactorPassSpec(name: 'fix', command: 'dart fix --apply lib/'),
  ];

  /// The pass specs this registry will execute, in order. Before run(),
  /// this is either the caller's explicit specs or the static default set
  /// above; the resolved build command (if any) is materialized in run().
  List<RefactorPassSpec> get passSpecs => List<RefactorPassSpec>.unmodifiable(
    _explicitPassSpecs ?? defaultPassSpecs,
  );

  /// Resolve the effective pass specs (bug #689): explicit specs win;
  /// otherwise resolve the zfa entrypoint exactly like `zfa tdd make` and
  /// point the build pass at its `build` subcommand. If resolution fails,
  /// fall back to the static default specs — the executor then records the
  /// concrete misfire (failed start / non-zero exit) as pass evidence.
  Future<List<RefactorPassSpec>> _effectivePassSpecs() async {
    final explicit = _explicitPassSpecs;
    if (explicit != null) return explicit;
    try {
      final entrypoint = await resolveZfaEntrypoint(
        commandLabel: 'zfa tdd refactor',
      );
      return [
        RefactorPassSpec(
          name: 'build',
          command: entrypoint.commandFor('build'),
        ),
        ...defaultPassSpecs.skip(1),
      ];
    } on PipelineResolutionError {
      return defaultPassSpecs;
    }
  }

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
    final specs = await _effectivePassSpecs();
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
