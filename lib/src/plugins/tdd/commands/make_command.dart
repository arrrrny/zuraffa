/// `zfa tdd make <behavior-id>` — generation-only green step of the
/// TDD loop (spec 047-tdd-make, FR-001..011; 041 Phase 8, T062-T065).
///
/// The command:
///   1. Resolves the target behavior's test path + runnable test name
///      from the artifact registry (FR-001, FR-002) — same resolution
///      rules as `verify-red`.
///   2. Requires certified-red evidence (a red entry from `verify-red`)
///      in `tdd/cycle-log.md` BEFORE generating anything (FR-001).
///      Missing precondition → `not-certified-red` non-zero exit
///      naming the remediation (US2.AC1).
///   3. Re-runs the target test before generating and confirms it
///      STILL fails (FR-003). An already-green test takes the SKIP
///      transition (issue #694, amending US2.AC3): generation is
///      skipped entirely, NO suite run happens — the scoped single-test
///      re-run is the evidence run (issue #741), a green evidence entry
///      with an explicitly empty generation block is appended, and the
///      command exits 0 with `outcome=skipped` so the run loop proceeds
///      past completed behaviors instead of deadlocking on re-runs.
///   4. Plans the minimal generation through the zuraffa pipeline
///      (FR-005): `entity create` / `make` / `build` (never hand-
///      writes source, never edits tests — FR-004).
///   5. Executes the plan via [PipelineRunner], capturing every
///      invocation as a [GenerationStep] (FR-006). Misfire-stop on
///      unexpressible behaviors (US4) or failing generation steps
///      (US4.AC2) — with one per-behavior guard (issue #737, amended by
///      issue #942): a failure of the plan's TERMINAL `build` step is
///      tolerated when the CURRENT behavior's own test passes (the
///      profile `single` command) AND the failed build's output carries
///      no analyzer errors — a non-compiling generated tree is not
///      tolerable noise and keeps the honest `generation-error` stop.
///   6. Runs the target test via the profile `single` command and
///      requires a PASS (FR-007). Then requires no NEW suite failures
///      that are attributable to this make, relative to a pre-run
///      baseline (US3; issue #731): a failure counts against the make
///      only when it lives in the current behavior's own test file or
///      in a file that was fully green at baseline. Failures confined
///      to files that were ALREADY red at baseline are pre-existing red
///      behaviors (e.g. deferred acceptance tests) and never block
///      the make — their failing-test identifiers may even vary
///      between the two suite runs. Issue #741: the baseline may come
///      from the run's cached snapshot (`--suite-baseline`, written
///      once per `zfa tdd run`) and the guard may be the scoped
///      single-test result; the live full suite runs only for a
///      standalone make or when the cache/scoped transcript is
///      unusable (safe fallback).
///   7. On success, appends a green-evidence entry to
///      `specs/<feature>/tdd/cycle-log.md` (FR-008) containing the
///      generation commands, runner command, runner exit code,
///      captured passing output, full-suite result, and timestamp.
///   8. On any failure, exits non-zero, appends no green entry, and
///      leaves the test file and cycle log unmodified (FR-009).
///   9. Prints the machine-readable summary line
///      `make: behavior=<id> outcome=<label> feature=<feature>`
///      as the final stdout line on every code path (FR-010); exit
///      code 0 means exactly "green certified" (US5.AC2).
///  10. Honors the misfire-stop policy: any internal step that cannot
///      complete stops the command immediately, non-zero, with a
///      clear report (FR-011).
///
/// Rejections and misfires are signaled through dart:io `exitCode`
/// (which [CliRunner] honors) rather than by throwing, so the summary
/// line stays the final stdout line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../../cli/exit_protocol.dart';

import '../models/generation_plan.dart';
import '../models/red_classification.dart';
import '../models/routing.dart';
import '../services/artifact_registry.dart';
import '../services/arg_placeholder.dart';
import '../services/born_green.dart';
import '../services/composition_planner.dart';
import '../services/composition_targets.dart';
import '../services/cycle_evidence.dart';
import '../services/cycle_log_sections.dart';
import '../services/dependency_override_preflight.dart';
import '../services/subject_shape.dart';
import '../services/cycle_log.dart';
import '../services/entity_lookup.dart';
import '../services/feature_path_resolver.dart';
import '../services/generation_planner.dart';
import '../services/journal.dart';
import '../services/nuance_receipts.dart';
import '../services/pipeline_runner.dart';
import '../services/red_classifier.dart';
import '../services/run_baseline_cache.dart';
import '../services/skin_authoring.dart';
import '../services/tdd_generation_receipt.dart';
import '../services/runner.dart';
import '../services/declared_routing.dart';
import '../services/spec_parser.dart';
import '../services/test_list_reader.dart';
import '../services/suite_guard.dart';
import '../services/tdd_timeout.dart';
import '../services/vacuous_guard.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../services/widget_scaffold.dart';
import '../tdd_plugin.dart';
import '../../../cli/plugin_loader.dart';
import '../../../commands/build_command.dart' show BuildCommand;
import '../../../config/zfa_config.dart';
import '../../../core/plugin_system/plugin_manager.dart';
import '../../../core/plugin_system/plugin_registry.dart';
import '../../../core/project/project_root.dart';
import '../../../core/dependencies/builder_dependency_preflight.dart';

/// Resolution-stage failure: message, outcome, and feature context if known.
class MakeResolutionError implements Exception {
  MakeResolutionError(this.message, {required this.outcome, this.feature});

  final String message;
  final MakeOutcome outcome;
  final String? feature;

  @override
  String toString() => message;
}

class MakeCommand extends Command<void> {
  MakeCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 047-tdd-make). Restricts target '
          'resolution to specs/<feature>/tdd/artifacts.json. When '
          'omitted, every feature registry is scanned.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and .specify/ (the fixture '
          'or target project). When omitted, the current working directory is '
          'used. Tests pass the temp fixture root here instead of mutating '
          'Directory.current, which is process-global and unsafe under '
          'concurrent test execution.',
    );
    argParser.addOption(
      'zfa-bin',
      help:
          'Override the zfa entrypoint for pipeline sub-processes. Tests use '
          'this to point at a fake zfa script; production runs auto-resolve '
          'via Platform.script or `zfa` on PATH.',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'minutes',
      help:
          'Hard deadline in minutes for every process this command spawns — '
          'the target test (default 2 min), the full suite baseline/guard and '
          'each generation pipeline step (default 10 min each). Fractions are '
          'allowed (0.5 = 30 seconds). On timeout the child is killed '
          '(SIGKILL) and the command stops non-zero as runner-error (bug '
          '#742).',
    );
    argParser.addOption(
      'baseline-scope',
      help:
          'Issue #1374: scope the LIVE suite baseline to a directory '
          '(canonically the feature test dir) so the first baseline can '
          'be produced on constrained agents.',
    );
    argParser.addOption(
      'suite-baseline',
      help:
          'Path to a cached full-suite baseline snapshot (run-baseline.json) '
          'written once per run by `zfa tdd run` (issue #741). When given and '
          'readable, make reuses the cached pre-run failure set instead of '
          'running the full suite, and certifies the post-generation guard '
          'from the scoped single-test result — falling back to the live '
          'suite when the cache is missing, corrupt, or unparseable.',
    );
    argParser.addFlag(
      'strict-routing',
      help:
          'Refuse undeclared routing intent (no `**Type**` marker, contract '
          'trace, or kind declaration) instead of falling back to the legacy '
          'description-keyed branches and the composition fallback '
          '(feature 071, issue #951).',
      negatable: false,
    );
    argParser.addFlag(
      'stub',
      help:
          'Demote generation to shallow func-stubs (the legacy escape hatch). '
          'Default generates contract-conforming mocks via zfa mock create.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'author',
      help:
          'Sanctioned skin-authoring mode (issue #1258): transition a '
          'SCAFFOLDED widget test (the zfa:tdd: scaffolded marker) from '
          'placeholder finders to the author-supplied concrete finders in '
          '--finders-file, re-certify red-before-green honestly, write the '
          'hand-delta receipt into the provenance ledger, clear the marker, '
          'and continue through the normal make flow. Without --author a '
          'scaffolded test is still refused (issue #912 defect 3).',
      negatable: false,
    );
    argParser.addOption(
      'finders-file',
      help:
          'Path to a file holding the author-supplied concrete finder '
          'statements (find.text / find.byType ... assertions) that '
          'replace the scaffolded placeholder block. Required with '
          '--author; the file must not carry the scaffold marker and must '
          'contain at least one expect/expectLater call.',
    );
    argParser.addFlag(
      'born-green',
      help:
          'The issue #1411 born-green hand transition — the no-prior-red '
          'analogue of verify-red\'s --re-certify (issue #1162): certify '
          'green for a behavior whose DESIGNED hand step (real outcome '
          'assertion, vacuous-guard marker removed, subject '
          'hand-implemented) was completed BEFORE the first red '
          'certification. Requires the target test to PASS an honest '
          're-run, the vacuous-guard marker to be absent, the '
          '`<id>:hand` attestation header to be present, and a '
          'non-placeholder subject; refuses safe-failure otherwise. '
          'Inert when certified red already exists (the red-first '
          'ordering owns the behavior).',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'make';

  @override
  String get description =>
      'Generate minimal implementation via zfa make/entity create/build, '
      'run the target test green, certify the suite stays clean, and '
      'append green evidence to tdd/cycle-log.md (spec 047).';

  @override
  String get invocation =>
      'zfa tdd make [<behavior-id>] [--feature <name>] '
      '[--project <path>] [--zfa-bin <path>] '
      '[--author --finders-file <path>] [--born-green]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    final behaviorId = rest.isNotEmpty ? rest.first : null;
    final featureFlag = argResults?['feature'] as String?;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      try {
        _validateFeatureSegment(featureFlag);
      } on UsageException catch (e) {
        print('zfa tdd make: ${e.message}');
        _printSummary(
          behavior: behaviorId ?? '-',
          outcome: MakeOutcome.runnerError,
          feature: 'unknown',
        );
        exitCode = 1;
        return;
      }
    }
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');

    // Issue #1471: the --feature reference may name a bug directory
    // (`.specify/bugs/<slug>`) that lives outside `specs/`. The canonical
    // NAME labels the summary lines; the canonical REFERENCE is what a
    // spawned child (`zfa tdd view ... --feature`) must resolve back.
    final resolvedFeature = featureFlag != null && featureFlag.isNotEmpty
        ? TddFeaturePaths.resolveWithPin(
            projectRoot: cwd,
            featureRef: featureFlag,
          )
        : null;
    final featureRef = resolvedFeature?.ref ?? featureFlag;
    final featureLabel = resolvedFeature?.name ?? featureFlag;

    // -----------------------------------------------------------------
    // Issue #1303 preflight: a stale `dependency_overrides` path entry
    // makes every pipeline step die with a raw version-solving dump
    // buried mid-log, and the clean-cache retry burns a full rebuild on
    // a resolution error no cache clean can fix. Validate every
    // override path BEFORE anything spawns; refuse with the honest
    // drift verdict (exit 3) instead.
    // -----------------------------------------------------------------
    final overrideReport = await DependencyOverridePreflight(
      projectRoot: cwd,
    ).check();
    if (!overrideReport.ok) {
      final behavior = behaviorId ?? '-';
      for (final finding in overrideReport.findings) {
        print(DependencyOverridePreflight.findingLine(finding));
      }
      print('$kOverrideFixLine `zfa tdd make`');
      _printSummary(
        behavior: behavior,
        outcome: MakeOutcome.preflightRed,
        feature: featureLabel ?? 'unknown',
      );
      exitCode = 3;
      return;
    }

    final zfaBinFlag = argResults?['zfa-bin'] as String?;
    final suiteBaselineFlag = argResults?['suite-baseline'] as String?;
    // Issue #1374: the constrained-agent escape hatch for the live
    // baseline branch below.
    final baselineScope = argResults?['baseline-scope'] as String?;
    if (baselineScope != null) {
      final scopeNorm = p.normalize(baselineScope);
      if (p.isAbsolute(scopeNorm) ||
          scopeNorm == '..' ||
          scopeNorm.startsWith('../')) {
        print(
          'zfa tdd make: --baseline-scope must be a directory relative to '
          'the project root (got "$baselineScope")',
        );
        exitCode = ExitProtocol.usage;
        return;
      }
    }
    final suiteBaselinePath =
        suiteBaselineFlag != null && suiteBaselineFlag.isNotEmpty
        ? suiteBaselineFlag
        : null;

    // Bug #742: the --timeout override — one uniform deadline for every
    // subprocess this command spawns (single test, suite, pipeline steps).
    Duration? timeoutOverride;
    try {
      timeoutOverride = parseTddTimeoutMinutes(
        argResults?['timeout'] as String?,
      );
    } on TddTimeoutFormatException catch (e) {
      print('zfa tdd make: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        outcome: MakeOutcome.runnerError,
        feature: featureLabel ?? 'unknown',
      );
      exitCode = 1;
      return;
    }

    final runner = const SingleTestRunner();
    final planner = const GenerationPlanner();
    final pipelineRunner = const PipelineRunner();
    final guard = const SuiteGuard();

    // ---------------------------------------------------------------
    // 1. Resolve the target from the registry (FR-001, FR-002).
    // ---------------------------------------------------------------
    _ResolvedTarget target;
    try {
      target = await _resolveTarget(cwd, behaviorId, featureFlag);
    } on MakeResolutionError catch (e) {
      print('zfa tdd make: ${e.message}');
      _printSummary(
        behavior: behaviorId ?? '-',
        outcome: e.outcome,
        feature: e.feature ?? featureLabel ?? 'unknown',
      );
      exitCode = 1;
      return;
    }
    final record = target.record;
    print('zfa tdd make: behavior ${record.behaviorId}');
    print('   feature: ${target.featureName}');
    print('   test: ${record.testPath}');

    final testPath = p.isAbsolute(record.testPath)
        ? record.testPath
        : p.join(cwd, record.testPath);
    final testName = _runnableNameOf(record);

    // ---------------------------------------------------------------
    // 2. Precondition: certified-red evidence (FR-001, US2.AC1).
    //    Issue #1258: under --author a SCAFFOLDED target may still earn
    //    its certified red below — the authored red is appended to the
    //    cycle-log BEFORE any generation — so the refusal defers to the
    //    authoring block for exactly that shape (and only that shape:
    //    the block itself re-checks the marker).
    //    Issue #1411: under --born-green the refusal defers to the
    //    born-green transition block — the hand-first ordering's
    //    explicit recovery — and the plain refusal OFFERS the exact
    //    `--born-green` command when the attested hand-first shape
    //    (marker absent + header present) is on disk.
    // ---------------------------------------------------------------
    final authorMode = argResults?['author'] as bool? ?? false;
    final bornGreenFlag = argResults?['born-green'] as bool? ?? false;
    final findersFileFlag = argResults?['finders-file'] as String?;
    final authorTestFile = File(testPath);
    final testIsScaffolded =
        authorTestFile.existsSync() &&
        contentIsScaffolded(await authorTestFile.readAsString());
    final certifiedRed = await _hasCertifiedRed(
      target.featureDir,
      record.behaviorId,
    );
    // Issue #1411: the hand-first shape probe over the CURRENT test
    // bytes — captured once (null when the file is missing/unreadable)
    // and shared by the offer below and the transition block.
    String? handFirstTestContent;
    if (!certifiedRed && authorTestFile.existsSync()) {
      try {
        handFirstTestContent = await authorTestFile.readAsString();
      } on FileSystemException {
        handFirstTestContent = null;
      }
    }
    final handFirstAttested =
        handFirstTestContent != null &&
        !contentCarriesVacuousGuardMarker(handFirstTestContent) &&
        contentCarriesHandStepHeader(handFirstTestContent, record.behaviorId);
    if (!certifiedRed && !(authorMode && testIsScaffolded) && !bornGreenFlag) {
      print(
        'zfa tdd make: behavior "${record.behaviorId}" has no certified-red '
        'evidence in cycle-log.md. Run `zfa tdd verify-red '
        '${record.behaviorId}` first.',
      );
      // Issue #1411: the born-green OFFER. The refusal keeps its
      // original first line (the red-first remedy stands for the
      // red-first ordering); the offer names the exact recovery command
      // when the attested hand-first shape is on disk (compare issue
      // #1373's UX gap).
      if (handFirstAttested) {
        print(
          '   born-green hand transition (issue #1411): the test carries '
          'the ${record.behaviorId}:hand attestation and the vacuous-guard '
          'marker is absent — if the designed hand step was completed '
          'before the first red certification (the target test passes '
          'now), certify green with:',
        );
        print('   --> zfa tdd make ${record.behaviorId} --born-green');
      }
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.notCertifiedRed,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 3. Load the profile (single + suite) — misfire-stop U30.
    // ---------------------------------------------------------------
    String singleTemplate;
    String suiteTemplate;
    try {
      singleTemplate = await runner.loadSingleTemplate(workingDirectory: cwd);
      suiteTemplate = await runner.loadSuiteTemplate(workingDirectory: cwd);
    } on StateError catch (e) {
      print(e.message);
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    // Issue #1402: the whole-file fallback template. OPTIONAL by design:
    // a profile without a `file:` key degrades to the remedy-only path —
    // the zero-match guard never fabricates a runner invocation.
    String? fileTemplate;
    try {
      fileTemplate = await runner.loadFileTemplate(workingDirectory: cwd);
    } on StateError {
      fileTemplate = null;
    }

    // ---------------------------------------------------------------
    // 3a. Sanctioned skin-authoring transition (issue #1258). A
    //     SCAFFOLDED widget test — the `zfa:tdd: scaffolded` marker —
    //     could never reach green: gen emits placeholder finders, the
    //     refusal demanded a replacement NO command performed, and
    //     hand-editing a registry-owned test is an out-of-contract
    //     mutation (no receipt, no adopt path, replay divergence).
    //     Under --author the make performs the transition through the
    //     pipeline, in order:
    //       (a) replace the scaffolded scenario block with the
    //           author-supplied concrete finders (--finders-file) and
    //           clear the marker ([SkinAuthoring]);
    //       (b) re-certify red-before-green HONESTLY — the authored
    //           test must FAIL right now, and only an assertion-
    //           classified red certifies (the same discipline as
    //           verify-red's classify gate); the born-green vacuity
    //           (the authored test passing against the certified-red
    //           subject shape, issue #1036 class) and any compile/load
    //           failure restore the scaffolded bytes and refuse —
    //           safe-failure, never a silent pass;
    //       (c) append the authored red evidence to the cycle-log and
    //           write the hand-delta receipt into the feature's
    //           provenance ledger (the realize --scaffold pattern);
    //       (d) fall through with the marker cleared — the certified-red
    //           precondition above now passes on the authored red, and
    //           the normal make flow (drift check → plan → generation →
    //           green) resumes so the run driver no longer stops at
    //           `<id>:make`.
    //     Without --author the 3b refusal below stands unchanged.
    // ---------------------------------------------------------------
    if (authorMode) {
      if (!testIsScaffolded) {
        print(
          'zfa tdd make: behavior "${record.behaviorId}" test carries no '
          'scaffold marker ($scaffoldedMarker) — --author transitions a '
          'SCAFFOLDED skin test to concrete finders, and there is nothing '
          'to author here. Re-run make without --author.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      if (findersFileFlag == null || findersFileFlag.isEmpty) {
        print(
          'zfa tdd make: --author requires --finders-file <path> — the '
          'author-supplied concrete finders (find.text / find.byType ... '
          'statements) that replace the scaffolded placeholder block.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      final findersFile = File(findersFileFlag);
      if (!findersFile.existsSync()) {
        print(
          'zfa tdd make: --finders-file not found: $findersFileFlag. '
          '--> fix: pass the path of the file holding the author-'
          'supplied concrete finders.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      final authorFinders = await findersFile.readAsString();
      final originalContent = await authorTestFile.readAsString();
      final String patchedContent;
      try {
        patchedContent = SkinAuthoring.patchedContent(
          testContent: originalContent,
          authorFinders: authorFinders,
        );
      } on SkinAuthoringException catch (e) {
        print('zfa tdd make: authoring refused — ${e.message}');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      // (a) The registry-owned test is mutated HERE — inside the
      //     pipeline, receipted below — never by hand.
      await authorTestFile.writeAsString(patchedContent);
      print(
        '   skin authoring (issue #1258): scaffolded placeholder block '
        'replaced with concrete finders from $findersFileFlag — '
        're-certifying red-before-green',
      );

      // (b) Honest red-before-green: the authored test must fail NOW
      //     (the view is still the inert certified-red subject).
      final authoringRun = await _runTargetTest(
        runner: runner,
        singleTemplate: singleTemplate,
        fileTemplate: fileTemplate,
        testPath: testPath,
        testName: testName,
        workingDirectory: cwd,
        timeout: timeoutOverride,
      );
      final authoringClass = classify(authoringRun);
      if (authoringClass != RedClassification.assertion) {
        await authorTestFile.writeAsString(originalContent);
        final why = authoringClass == RedClassification.unexpectedGreen
            ? 'the authored test PASSES against the certified-red subject '
                  'shape — the born-green vacuity (issue #1036 class): the '
                  'supplied finders are satisfiable by the inert stub and '
                  'prove nothing about the scenario'
            : 'the authored test did not certify an honest red '
                  '(classification: ${authoringClass.label})';
        print(
          'zfa tdd make: skin authoring refused for behavior '
          '"${record.behaviorId}" — $why. The scaffolded test was '
          'restored byte-identical; supply scenario-failing concrete '
          'finders in --finders-file and re-run.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.scaffolded,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }

      // (c) The authored red is honest: append it (the certified-red
      //     precondition above re-reads the log) and write the hand-delta
      //     receipt into the provenance ledger.
      final redEvidence = failingAssertionOf(authoringRun.output);
      await CycleLog(target.featureDir).append(
        CycleLogEntry(
          behaviorId: record.behaviorId,
          kind: CycleEntryKind.red,
          runnerCommand: authoringRun.command,
          exitCode: authoringRun.exitCode,
          capturedOutput: authoringRun.output,
          classification: FailureClass.assertionFailure,
          redEvidence: redEvidence,
          subjectHash: await _subjectHashAt(cwd, record),
          sourceCriterion: record.sourceCriterion,
          testPath: record.testPath,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      print(
        '   authored red certified (assertion) — red evidence appended to '
        '${TddFeaturePaths.displayDir(cwd: cwd, dir: target.featureDir)}/tdd/cycle-log.md',
      );
      try {
        await NuanceReceipts(
          featureDir: target.featureDir,
          projectRoot: cwd,
        ).record(
          file: p.relative(testPath, from: cwd).replaceAll('\\', '/'),
          reason:
              'skin-authored by zfa tdd make --author (issue #1258): the '
              'scaffolded placeholder finders were replaced with '
              'author-supplied concrete finders and the marker cleared; '
              'the authored red was re-certified before generation',
          adapter: record.behaviorId,
          recordedBy: 'zfa tdd make --author',
        );
        print(
          '   hand-delta receipt recorded in ${TddFeaturePaths.displayDir(cwd: cwd, dir: target.featureDir)}/'
          'tdd/provenance-ledger.json',
        );
      } on NuanceReceiptException catch (e) {
        // The transition is complete and evidenced in the cycle-log, but
        // an unwritten receipt would leave an ungated hand-delta behind —
        // the ledger is the provenance contract. Surface it (safe
        // failure); the next make --author re-records it idempotently.
        print('zfa tdd make: provenance ledger write failed — $e');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
    }

    // ---------------------------------------------------------------
    // 3b. Scaffolded widget tests cannot certify green (issue #912
    //     defect 3). A generated widget test whose scenario assertions
    //     are still placeholder finders carries the machine-readable
    //     scaffold marker; a green such test proves nothing (a bare
    //     SizedBox() passes it). The behavior is EXCLUDED from
    //     contract-green accounting: refuse with the remedy, exit
    //     non-zero, no green evidence appended.
    // ---------------------------------------------------------------
    final scaffoldCheckFile = File(testPath);
    if (scaffoldCheckFile.existsSync() &&
        contentIsScaffolded(await scaffoldCheckFile.readAsString())) {
      print(
        'zfa tdd make: behavior "${record.behaviorId}" test is SCAFFOLDED '
        '— its scenario assertions are placeholder finders '
        '($scaffoldedMarker, issue #912 defect 3). Replace the '
        'placeholder finders with concrete scenario-derived finders '
        '(find.text / find.byType ...), remove the marker, and re-run '
        'make.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.scaffolded,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }

    // ---------------------------------------------------------------
    // 3b'. Issue #1411: the born-green hand transition — the
    //      no-prior-red analogue of verify-red's --re-certify (issue
    //      #1162). The designed hand step (guide §5a item 1: replace
    //      the vacuous-guard test with real assertions, hand-implement
    //      the subject) may be completed BEFORE the pipeline's first
    //      pass, leaving NO certified red: verify-red grades the
    //      already-passing test unexpected-green and the red-first gate
    //      above refuses — the catch-22 with no supported ordering.
    //      The EXPLICIT --born-green flag certifies green from an
    //      honestly re-run PASSING target test, gated safe-failure-first
    //      on the full hand-first shape:
    //        (a) the test is not vacuous (the vacuous-guard marker is
    //            absent and a real assertion set remains) — the hand
    //            step's test side is DONE;
    //        (b) the test carries the `U<n>:hand` attestation header —
    //            the machine-greppable sibling of the scaffolded /
    //            vacuous-guard markers;
    //        (c) the subject is NOT a born-green placeholder (the
    //            #1036 class: a throwing stub or vacuous scaffold whose
    //            paired test passes proves nothing);
    //        (d) the target test PASSES the honest re-run.
    //      Every failed check refuses with the exact remedy (never a
    //      silent pass); success appends green evidence in the EXISTING
    //      format (the #694/#741 skip pattern: empty generation block,
    //      honest zero suite numbers, subject-hash bound) and exits 0
    //      with the EXPLICIT `born-green` outcome.
    //      With certified red present the flag is INERT — the red-first
    //      ordering owns the behavior unchanged (US2.AC1) — and the
    //      --author flow owns the scaffolded shape above, so the block
    //      requires !authorMode (the authoring block falls through on
    //      success with a stale `certifiedRed` local).
    // ---------------------------------------------------------------
    if (bornGreenFlag && !certifiedRed && !authorMode) {
      final bornTestContent = handFirstTestContent;
      // (a) The vacuity gate: the marker-present (or assertion-free)
      //     test is the hand step's INPUT shape, not its end state.
      if (bornTestContent == null || contentIsVacuousGreen(bornTestContent)) {
        print(
          'zfa tdd make: behavior "${record.behaviorId}" --born-green '
          'refused: the test is VACUOUS-GREEN — the assertion set is '
          'still the UnimplementedError guard (the $vacuousGuardMarker '
          'marker is present), so the designed hand step is not complete '
          '(issue #1411).',
        );
        print(
          '   --> fix: replace the guard with an assertion on the '
          'observable outcome, remove the marker, add the attestation '
          'header, then re-run `zfa tdd make ${record.behaviorId} '
          '--born-green`.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.vacuousGreen,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      // (b) The attestation gate: the header is the hand author's
      //     machine-readable signature that THIS file went through the
      //     designed hand step — without it --born-green would be a
      //     blanket skip-red escape for every never-red behavior.
      if (!contentCarriesHandStepHeader(bornTestContent, record.behaviorId)) {
        print(
          'zfa tdd make: behavior "${record.behaviorId}" --born-green '
          'refused: the test does not carry the <id>:hand attestation '
          'header (issue #1411) — the born-green transition certifies '
          'only the DESIGNED hand step (real outcome assertion, marker '
          'removed, subject hand-implemented).',
        );
        print('   --> fix: add the attestation header line to the test file');
        print('       ${handStepHeader(record.behaviorId)}');
        print(
          '       then re-run `zfa tdd make ${record.behaviorId} '
          '--born-green`.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.notCertifiedRed,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      // (c) The #1036 subject gate: a passing test against a throwing
      //     stub or vacuous scaffold is the born-green vacuity — the
      //     exact class the skip transition refuses.
      final subjectPath = p.isAbsolute(record.subjectPath)
          ? record.subjectPath
          : p.join(cwd, record.subjectPath);
      String? bornSubjectContent;
      try {
        bornSubjectContent = await File(subjectPath).readAsString();
      } on FileSystemException {
        bornSubjectContent = null;
      }
      if (bornSubjectContent != null &&
          subjectIsBornGreenPlaceholder(bornSubjectContent)) {
        print(
          'zfa tdd make: behavior "${record.behaviorId}" --born-green '
          'refused: the subject is still a born-green PLACEHOLDER (a '
          'throwing stub or vacuous scaffold — the issue #1036 class): '
          'the passing test proves nothing about the behavior.',
        );
        print(
          '   --> fix: hand-implement the subject\'s real body, then '
          're-run `zfa tdd make ${record.behaviorId} --born-green`.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.vacuousGreen,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      // (d) The honest evidence run: the transition certifies from the
      //     passing transcript, never from the driver's report.
      final bornRun = await _runTargetTest(
        runner: runner,
        singleTemplate: singleTemplate,
        fileTemplate: fileTemplate,
        testPath: testPath,
        testName: testName,
        workingDirectory: cwd,
        timeout: timeoutOverride,
      );
      if (bornRun.timedOut) {
        // Bug #742: the killed-child contract — runner-error, never a
        // silent pass.
        print(
          'zfa tdd make: behavior "${record.behaviorId}" — the born-green '
          'evidence run timed out: ${bornRun.output}',
        );
        print(
          '   re-run with a larger --timeout <minutes> if this step '
          'legitimately needs longer.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      if (singleTemplate.contains('--plain-name') && _noTestsRan(bornRun)) {
        // Issue #1402: the zero-match guard — no signal, no
        // certification.
        print(
          'zfa tdd make: behavior "${record.behaviorId}" — the born-green '
          'evidence run ran zero tests; the transition cannot be '
          'certified from this transcript.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      if (!bornRun.startedProcess || bornRun.exitCode != 0) {
        // The honest red-first remedy: a failing test is exactly what
        // verify-red certifies — the born-green transition never
        // replaces an earnable red.
        print(
          'zfa tdd make: behavior "${record.behaviorId}" --born-green '
          'refused: the target test FAILS — the born-green hand '
          'transition certifies a genuinely passing test (issue '
          '#1411).',
        );
        print(
          '   --> fix: certify red honestly with `zfa tdd verify-red '
          '${record.behaviorId}` (the red-first ordering), then re-run '
          'make.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.notCertifiedRed,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      print(
        '   born-green hand transition (issue #1411): the target test '
        'passes, the vacuous-guard marker is absent, and the '
        '${record.behaviorId}:hand attestation is present with no prior '
        'red evidence — certifying green from the passing transcript.',
      );
      final bornLog = CycleLog(target.featureDir);
      await bornLog.append(
        CycleLogEntry(
          behaviorId: record.behaviorId,
          kind: CycleEntryKind.green,
          runnerCommand: bornRun.command,
          exitCode: bornRun.exitCode,
          capturedOutput:
              'issue #1411 born-green hand transition — the designed hand '
              'step was completed before the first red certification '
              '(hand-first ordering); the passing transcript below is the '
              'green evidence bound to the current subject shape.\n'
              '${bornRun.output}',
          redEvidence:
              'issue #1411 born-green hand transition — no prior red '
              'evidence exists (the hand step preceded the first '
              'certification); green certified from the passing target '
              'test with the vacuous-guard marker absent and the '
              '${record.behaviorId}:hand attestation header present',
          subjectHash: await _subjectHashAt(cwd, record),
          sourceCriterion: record.sourceCriterion,
          testPath: record.testPath,
          timestamp: DateTime.now().toUtc().toIso8601String(),
          generationSteps: const [],
          suiteBaselineFailures: 0,
          suiteGuardFailures: 0,
          suiteNewFailures: const [],
        ),
      );
      // Issue #969 T003: the green evidence becomes self-certifying.
      await TddGenerationReceipts.writeBestEffort(
        projectRoot: cwd,
        command: 'tdd make --born-green',
        target: record.behaviorId,
        feature: target.featureName,
        files: {p.join(target.featureDir, 'tdd', 'cycle-log.md'): 'update'},
      );
      print(
        '   green evidence appended to specs/${target.featureName}/tdd/'
        'cycle-log.md',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.bornGreen,
        feature: target.featureName,
      );
      exitCode = 0;
      return;
    }

    // ---------------------------------------------------------------
    // 3c. Vacuous greens cannot certify green (issue #1259) — the
    //     unit-lane analogue of the scaffolded refusal above (issue
    //     #912 defect 3). A UNIT test whose assertion set is only the
    //     UnimplementedError guard proves only "the subject does not
    //     throw": a func-scaffolded dummy `return 0;` flips it green
    //     with zero declared-contract code, yet the receipt reported
    //     complete. The red surface may START at the guard (the stub
    //     throws, the capture returns the error, the guard fails —
    //     honest red); green requires at least one assertion on the
    //     observable outcome named by the behavior description. Scoped
    //     to UNIT rows (kindless/legacy rows fail open — no test list,
    //     no refusal); acceptance rows keep the legacy skip transition
    //     (the composition lane is deferred by design, FR-009).
    // ---------------------------------------------------------------
    final BehaviorKind? vacuousRowKind = await _rowKindQuiet(
      target.featureDir,
      record.behaviorId,
    );
    if (vacuousRowKind == BehaviorKind.unit && scaffoldCheckFile.existsSync()) {
      final testContent = await scaffoldCheckFile.readAsString();
      if (contentIsVacuousGreen(testContent)) {
        final description = _descriptionFor(record);
        print(
          'zfa tdd make: behavior "${record.behaviorId}" test is '
          'VACUOUS-GREEN — its assertion set is only the UnimplementedError '
          'guard (issue #1259). A green here proves nothing about the '
          'behavior: the guard passes on any non-throwing body (a dummy '
          '`return 0;` flips it green with zero declared-contract code).',
        );
        print(
          '   --> fix: add at least one assertion on the observable outcome '
          'named by the behavior description ("$description"), remove the '
          '$vacuousGuardMarker marker if present, and re-run make.',
        );
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.vacuousGreen,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
    }

    // ---------------------------------------------------------------
    // 4. Drift check: re-run target test BEFORE generation (FR-003).
    //    If it passes, the behavior is already satisfied (a prior make
    //    run or an equivalent implementation): SKIP transition (issue
    //    #694). Generation never runs; the full suite is re-certified
    //    with no NEW failures below, a green evidence entry with an
    //    explicitly empty generation block is appended, and the summary
    //    reports `outcome=skipped` with exit 0 so `zfa tdd run`
    //    proceeds past already-completed behaviors instead of stopping.
    //    Issue #1323 (spec 991 FR-005): this re-run is ALSO the
    //    re-certification after a hand-delta — when the user applied
    //    the `_argN()` remedy by hand-editing the generated test, the
    //    certified-red entry in the cycle-log NEVER short-circuits this
    //    verification: the UPDATED test is re-run right here and the
    //    cycle is re-certified red (proceed to generation) or green
    //    (the skip transition) from it.
    // ---------------------------------------------------------------
    final driftRun = await _runTargetTest(
      runner: runner,
      singleTemplate: singleTemplate,
      fileTemplate: fileTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: cwd,
      timeout: timeoutOverride,
    );
    if (driftRun.timedOut) {
      // Bug #742: the drift-check child outlived the deadline and was
      // killed — misfire-stop naming behavior, step, and command.
      print(
        'zfa tdd make: behavior "${record.behaviorId}" — drift check '
        '(target test re-run before generation) timed out: '
        '${driftRun.output}',
      );
      print(
        '   re-run with a larger --timeout <minutes> if this step '
        'legitimately needs longer.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    // Issue #1402: a STILL-zero-match drift record means the whole-file
    // fallback could not produce observable evidence either (or the
    // profile carries no `file:` template) — the targeted remedy is
    // already printed. Misfire-stop NOW, the same no-signal contract as
    // the #742 timeout stop above: spending generation on a behavior no
    // runner invocation can observe dead-ends in the same phantom at the
    // post-generation re-run, one wasted pipeline later.
    if (singleTemplate.contains('--plain-name') && _noTestsRan(driftRun)) {
      print(
        'zfa tdd make: behavior "${record.behaviorId}" — the drift check '
        '(target test re-run before generation) ran zero tests; the cycle '
        'cannot be re-certified from this transcript.',
      );
      _printSummary(
        behavior: record.behaviorId,
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
      exitCode = 1;
      return;
    }
    // Issue #1345: the placeholder re-drive re-entry demotes this to
    // false so the make falls through to generation planning — the
    // composition fallback re-enters the acceptance pipeline at
    // compose/make phase-2 (the same path a first drive runs).
    var alreadyGreen = driftRun.exitCode == 0 && driftRun.startedProcess;
    // Issue #1331: the complete-but-unowned re-drive class. When the
    // behavior's surviving certification was invalidated by the LAST
    // reset tombstone (the registry was dropped, the behavior re-driven
    // from gen), the certified-hash basis of the #1036 subject-drift
    // guard is stale by decree — the re-drive adopts the passing subject
    // (the EXPLICIT `adopted` outcome) instead of dead-ending the
    // documented reset → run recovery loop. Every other class — a
    // green-basis drift whose evidence postdates the reset, a feature
    // with no tombstone, the born-green placeholders — keeps refusing.
    var adoptedReDrive = false;
    // Issue #1345: the placeholder re-drive class — a tombstoned
    // ACCEPTANCE-kind re-drive whose on-disk subject IS the born-green
    // compose-pipeline placeholder (the exact bytes gen emits, the input
    // shape compose rewrites). Neither the #1331 adoption (it would
    // certify green on a vacuous subject — the #1036 guard's exact
    // refusal class) nor the #1036 refusal (it dead-ends the documented
    // reset → doctor → run recovery loop) applies: the make RE-ENTERS
    // the acceptance pipeline at compose/make phase-2 by falling through
    // to generation planning, and the outcome is the EXPLICIT
    // `adopted-placeholder`.
    var placeholderReDrive = false;
    if (alreadyGreen) {
      final reDrive = await _tombstonedReDrive(target.featureDir, record);
      // A tombstone invalidates the certified HASH basis, not the #1036
      // subject-shape guard: a born-green placeholder subject (scaffolded
      // marker, still-throwing stubs) must never be adopted into green —
      // the passing test would be vacuous against it. Placeholders take
      // the #1345 re-entry (acceptance rows) or keep the drift refusal
      // below.
      final placeholderOnDisk = reDrive
          ? await _subjectIsBornGreenPlaceholderOnDisk(cwd, record)
          : false;
      final adoptable = reDrive && !placeholderOnDisk;
      if (adoptable) {
        adoptedReDrive = true;
        print(
          '   re-drive adoption (issue #1331): the last reset tombstone '
          'invalidated the surviving certification for '
          '"${record.behaviorId}" — the passing target test re-certifies '
          'green against the on-disk subject (outcome=adopted); the '
          'appended evidence binds the current subject shape, so any '
          'post-adoption drift still refuses.',
        );
      } else if (reDrive &&
          placeholderOnDisk &&
          await _rowKindQuiet(target.featureDir, record.behaviorId) ==
              BehaviorKind.acceptance) {
        // Issue #1345: the placeholder re-drive class — the re-entry.
        // The subject on disk is the compose pipeline's OWN placeholder
        // for a behavior the last reset tombstoned, so the make runs the
        // SAME acceptance pipeline a first drive runs (the composition
        // fallback re-enters compose → build; compose re-implements the
        // stub against the feature's green unit anchors, or reports
        // already-composed for a surviving composed product) and the
        // cycle re-certifies from the pipeline's actual output with the
        // EXPLICIT `adopted-placeholder` outcome — never from the
        // vacuous pass itself. Zero composable anchors disengages the
        // fallback at the honest `unexpressible` stop (FR-009,
        // unchanged).
        placeholderReDrive = true;
        alreadyGreen = false; // issue #1345: fall through to generation
        print(
          '   re-drive compose re-entry (issue #1345): the on-disk '
          'subject is the compose pipeline\'s own placeholder for a '
          'tombstoned re-drive, so neither adoption (issue #1331) nor '
          'the subject-drift refusal (issue #1036) applies — '
          're-entering the acceptance pipeline at compose/make phase-2 '
          '(outcome=adopted-placeholder).',
        );
      } else {
        if (reDrive) {
          print(
            '   re-drive adoption withheld: the on-disk subject is a '
            'born-green placeholder, so the passing target test proves '
            'nothing (issue #1036) — the subject-drift refusal stands.',
          );
        }
        // Issue #1036: the skip transition must verify the subject under
        // test is the SAME shape the certified evidence captured. A make
        // that rewrote the subject (the acceptance func-scaffold rewrite
        // class) and then failed leaves a placeholder whose vacuous test
        // passes — the drift check alone would certify green on a subject
        // the red evidence never exercised. Refuse with the remedy
        // instead; legacy hashless entries fail open (the pre-#1036
        // behavior stands), so unit skip semantics are unchanged.
        final driftRefusal = await _subjectDriftRefusal(
          cwd,
          target.featureDir,
          record,
        );
        if (driftRefusal != null) {
          print(driftRefusal);
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.subjectDrift,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        print(
          '   target test already passes — skipping generation (issue #694 '
          'skip transition); the suite is not re-run (issue #741)',
        );
      }
    }

    // ---------------------------------------------------------------
    // 5. Pre-run suite baseline (FR-007 / US3.AC3). Issue #741: the
    //    already-green skip transition runs no suite at all, and a
    //    run-cached baseline (`--suite-baseline`, written once per
    //    `tdd run` by the driver) replaces the per-behavior suite run.
    //    The live suite runs only for a standalone make (no flag) or
    //    when the cache is missing/corrupt/unparseable — the same
    //    safe fallback as before this fix.
    // ---------------------------------------------------------------
    SuiteSnapshot? baseline;
    var baselineFromCache = false;
    if (!alreadyGreen) {
      SuiteSnapshot? cached;
      if (suiteBaselinePath != null) {
        cached = await const RunBaselineCache().read(suiteBaselinePath);
        if (cached == null || !cached.parseable) {
          print(
            '   suite baseline cache unreadable — falling back to the '
            'live suite',
          );
        }
      }
      if (cached != null && cached.parseable) {
        baseline = cached;
        baselineFromCache = true;
        print(
          '   suite baseline: cached (${baseline.capturedAt}) — '
          '${baseline.failedTests.length} pre-existing failure(s) '
          '(issue #741)',
        );
      } else {
        // Issue #1374: the constrained-agent escape hatch — scope the
        // baseline suite command to a path.
        final scopedTemplate = baselineScope == null
            ? suiteTemplate
            : '$suiteTemplate $baselineScope';
        print('   suite baseline: $scopedTemplate');
        final baselineRun = await runner.runSuite(
          suiteTemplate: scopedTemplate,
          workingDirectory: cwd,
          // Issue #1159: the --timeout override is ONE uniform deadline
          // (bug #742 contract) — the fallback live baseline included.
          // Without it the hardcoded 10-minute defaultSuite killed the
          // baseline on repos whose fast suite runs long, and make refused.
          timeout: timeoutOverride,
        );
        final live = guard.fromRunRecord(
          record: baselineRun,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        print(
          '   baseline exit: ${live.exitCode}, failed: ${live.failedTests.length}',
        );
        if (!baselineRun.startedProcess ||
            !live.parseable ||
            live.exitCode != 0 && live.failedTests.isEmpty) {
          print(
            'zfa tdd make: the suite baseline did not produce a usable snapshot. '
            'Refusing to generate without a trustworthy pre-run failure set.',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.runnerError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        baseline = live;
      }
    }

    // ---------------------------------------------------------------
    // 6-8. Plan, pipeline, and post-generation re-run — the generation
    //      path only. An already-green target (issue #694 skip
    //      transition) never plans or generates; its evidence command is
    //      the drift re-run itself and its generation block is empty.
    // ---------------------------------------------------------------
    PipelineResult? pipelineResult;
    var postRun = driftRun;
    // Issue #737: set when the plan's terminal `build` step failed but
    // the per-behavior guard tolerated it (the behavior's own test
    // passes, and the failed build's output carried no analyzer errors
    // — the issue #942 gate) — the make then records the honest
    // `green-with-failed-build` outcome instead of conflating the
    // failure with real green.
    var buildStepTolerated = false;
    if (!alreadyGreen) {
      // 6. Plan the minimal generation (FR-005). The row's loop kind
      // rides along (bug #835): an ffi-kind row must route to the
      // honest unexpressible plan, never to the id-prefix dispatch that
      // would send a U<n> ffi behavior into `tdd func` (whose scaffold
      // refuses the harness shape) and dead-end the run in a
      // generation-error. The reader is the single format contract; an
      // unreadable list degrades to kindless routing (exactly the
      // pre-#835 behavior) with a note instead of a silent guess.
      final rowKind = await _rowKind(target.featureDir, record.behaviorId);
      final isStub = argResults?['stub'] as bool? ?? false;
      final strictRouting = argResults?['strict-routing'] as bool? ?? false;
      // Round-2 review fix 3b: a MALFORMED spec (the parser's
      // StateError refusals) refuses the make — the same surfacing
      // path as a pipeline resolution error — instead of silently
      // routing on empty declarations (the #920 regression class).
      final SpecDeclarations declarations;
      try {
        declarations = await _declarationsFor(target.featureDir);
      } on StateError catch (e) {
        print('zfa tdd make: declaration refused — ${e.message}');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
      final summary = BehaviorSummary.fromRecord(
        record,
        description: _descriptionFor(record),
        target: _targetFor(record),
        entityTraced: await _tracedEntityFor(
          record: record,
          featureDir: target.featureDir,
        ),
        kind: rowKind,
        stub: isStub,
        strictRouting: strictRouting,
        traces: await _rowTraces(target.featureDir, record.behaviorId),
        declarations: declarations,
      );
      final plan = planner.plan(summary);
      GenerationPlan effectivePlan;
      if (plan.isExpressible) {
        effectivePlan = await _gateExistingEntityCreateSteps(
          plan,
          workingDirectory: cwd,
        );
        print('   plan: ${effectivePlan.steps.length} step(s)');
      } else {
        // ---------------------------------------------------------
        // Composition fallback (issue #642, spec 052): the planner is
        // pure and description-keyed, so an acceptance behavior's
        // prose stays unexpressible to it BY DESIGN —
        // deterministically across run phases. When the target's
        // test-list row is acceptance-kind and the feature holds
        // composable green unit subjects, offer the composition plan
        // (compose → build) that wires the acceptance subject against
        // them, so a deferred phase-2 acceptance make can actually
        // flip green.
        //
        // Issue #939 (the widget make path): a WIDGET-kind row — the
        // bug #830 testWidgets lane — dead-ended here forever (the
        // gate refused it, mislabeled as unit-kind). It now routes to
        // the view-builder lane: a deterministic minimal view
        // generated from the spec's declared Presentation layer
        // contract + the behavior's scenario literals, then build —
        // the loop REACHES green through a generated skeleton, exactly
        // as func subjects do. Everything else keeps the honest stop:
        // unit-kind behaviors and unknown rows (fail-closed), and
        // acceptance prose with zero composable anchors (FR-009),
        // report `unexpressible` exactly as before.
        // ---------------------------------------------------------
        // Feature 071 strict gate: under --strict-routing a resolver
        // refusal (errors-are-an-API: the reason carries `--> fix:`) is
        // the honest stop — the composition fallback (legacy lanes)
        // must not engage. Declared widget rows still route to the view
        // lane: their unexpressible plan is the ROUTING (the #950/#939
        // contract), not a strict failure.
        if (summary.strictRouting &&
            (plan.unexpressibleReason ?? '').contains('--> fix:')) {
          print(
            'zfa tdd make: cannot plan a generation for behavior '
            '"${record.behaviorId}". ${plan.unexpressibleReason}',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.unexpressible,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        final composed = await _compositionFallback(
          cwd: cwd,
          record: record,
          featureDir: target.featureDir,
          featureName: target.featureName,
          featureRef: featureRef ?? target.featureName,
          summary: summary,
        );
        if (composed == null) {
          print(
            'zfa tdd make: cannot plan a generation for behavior '
            '"${record.behaviorId}". ${plan.unexpressibleReason}',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.unexpressible,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        effectivePlan = composed;
        print(
          '   plan: composition fallback — '
          '${effectivePlan.steps.length} step(s)',
        );
      }

      // Bug #826 remediation (3): an inner `zfa make <name>` whose own
      // plan resolves to ZERO active plugins ("❌ No active plugins to
      // run.") is a no-op, not a generation. Resolve the child's plan
      // in-process — the same cheap PlanResolver the real `zfa make` runs
      // before any analyzer load — and record the no-op WITHOUT spawning
      // the heavy subprocess at all. Fail-open: when the plan shape is not
      // the default make invocation, or the in-process resolution errors,
      // the subprocess path runs exactly as before.
      if (zfaBinFlag == null || zfaBinFlag.isEmpty) {
        final makeName = _bareMakeName(effectivePlan);
        if (makeName != null && _innerMakePlanIsEmpty(cwd, makeName)) {
          // Issue #1330: the #829 entity gate turns a sibling acceptance
          // behavior's plan into [make <E>, tdd wire ..., build] when the
          // contract-row entity ALREADY exists. The one-shot `zfa make <E>`
          // scaffold has nothing to generate on that already-generated
          // entity — but the plan still carries the subject-edit step that
          // turned the earlier siblings green. When such a step remains,
          // drop the dead make step (the entity is reused AS-IS — hand-
          // tuned fields preserved, the #829 contract) and let the pipeline
          // reach the subject edit instead of hard-stopping in a no-op
          // that phase 2 would re-attempt identically forever.
          final fallbackPlan = _subjectEditFallbackPlan(effectivePlan);
          if (fallbackPlan != null) {
            print(
              '   plan: `zfa make $makeName` resolves to no active plugins '
              '— nothing to generate on the already-generated entity '
              '(issue #1330).',
            );
            print(
              '   falling back to the subject edit (issue #1330): the '
              'entity is reused as-is (hand-tuned fields preserved) — '
              'dropping the no-op make step.',
            );
            effectivePlan = fallbackPlan;
          } else {
            print(
              '   plan: `zfa make $makeName` resolves to no active plugins '
              '— nothing to generate (bug #826).',
            );
            print('   verdict: no-op');
            print(
              '--> fix: enable generator plugins for this project in '
              '.zfa.json (e.g. "usecase": true) or implement the subject '
              'manually, then re-run; no subprocess was attempted.',
            );
            _printSummary(
              behavior: record.behaviorId,
              outcome: MakeOutcome.noOp,
              feature: target.featureName,
            );
            exitCode = 1;
            return;
          }
        }
      }

      // 7. Execute the plan via the pipeline (FR-006, US1 / U8-U13).
      //     Issue #1036: snapshot the subject first — a FAILED make must
      //     leave the subject byte-identical to what it found, so the
      //     throwing stub survives a generation-error untouched and the
      //     retry fails honestly instead of skipping green on a
      //     placeholder the red evidence never exercised.
      final subjectPath = p.isAbsolute(record.subjectPath)
          ? record.subjectPath
          : p.join(cwd, record.subjectPath);
      final subjectFile = File(subjectPath);
      final subjectSnapshot = await subjectFile.exists()
          ? await subjectFile.readAsString()
          : null;
      try {
        pipelineResult = await pipelineRunner.runPlan(
          plan: effectivePlan,
          workingDirectory: cwd,
          zfaBinOverride: zfaBinFlag,
          feature: target.featureName,
          timeout: timeoutOverride,
        );
      } on PipelineResolutionError catch (e) {
        print('zfa tdd make: ${e.message}');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.runnerError,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }

      // Misfire-stop on generation failure (FR-004, US4.AC2) — with the
      // issue #737 per-behavior guard for the plan's terminal build
      // step.
      if (!pipelineResult.completed) {
        final idx = pipelineResult.firstFailureIndex;
        final failed = idx >= 0 && idx < pipelineResult.steps.length
            ? pipelineResult.steps[idx]
            : null;
        // Bug #826: a step that died by KILL is not a generation failure.
        // The subprocess was killed — by the OS under memory pressure
        // (the SIGKILL/OOM class, exit < 0) or by our own deadline
        // (timeout, bug #742 path). Grading either as a bare
        // `generation-error` is what made the run loop's stop
        // indistinguishable from a genuine red. Emit the classified
        // verdict — class + exit code + `--> fix:` line + the telemetry
        // JSON — and surface it in the summary's outcome token so corpus
        // drivers can tell a transient, re-runnable kill from a real red.
        final killOutcome = switch (failed?.killClass) {
          GenerationKillClass.resourceLimit => MakeOutcome.resourceLimit,
          GenerationKillClass.timeout => MakeOutcome.timeout,
          _ => null,
        };
        if (killOutcome != null && failed != null) {
          print(
            'zfa tdd make: generation step killed at index $idx '
            '(${failed.purpose}):',
          );
          print('   command: `${failed.command}`');
          print('   verdict: ${failed.verdictLabel} (exit ${failed.exitCode})');
          print(
            failed.killClass == GenerationKillClass.timeout
                ? '--> fix: the step outlived its deadline — raise '
                      '--timeout (minutes) on slower machines, or investigate '
                      'the step for a hang.'
                : '--> fix: transient resource kill (SIGKILL/OOM class) — '
                      'free memory or raise ZFA_TDD_STEP_MEMORY_KB headroom, '
                      'then re-run this step; no state changed.',
          );
          print('   telemetry json: ${jsonEncode(failed.verdictJson())}');
          await _restoreSubjectIfMutated(
            subjectFile,
            subjectSnapshot,
            reason: 'the generation step was killed',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: killOutcome,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        // Issue #1407 — the make's analyze gate is ERRORS-ONLY. The plan's
        // terminal `build` step runs `zfa build`, whose analyze stage
        // (issues #395/#1035) refuses the tree on errors OR warnings; a
        // pre-existing engine-lane warning (0 errors + N warnings) then
        // failed the skin lane's make while the engine lane's own green
        // receipt had accepted the same warning — cross-lane warning
        // coupling, and 0 errors means the tree compiles. When the failed
        // step IS the plan's terminal build step (the same per-behavior
        // precondition the #737 guard uses) and its output proves the
        // refusal was the gate's own verdict with 0 error(s) and >=1
        // warning(s) (cross-checked through the shared
        // `BuildCommand.countAnalyzerIssues` parser — the single #1035
        // line-format contract), the warnings are LOGGED as non-blocking
        // findings and the make PROCEEDS through its normal flow: the
        // post-generation target test and the suite guard decide the
        // outcome, never the warning. A build verdict carrying analyzer
        // errors never reaches this arm — the #942 refusal below keeps
        // the honest `generation-error` stop byte-identically. A project
        // that relies on warnings being blocking opts back in via the
        // TDD profile's machine-readable Keys block
        // (`analyze-gate: warnings-blocking`), which skips this arm and
        // restores the pre-#1407 grading unchanged. The dart analyze
        // invocation, the build command, and the pipeline runner are
        // untouched — this is only how the make interprets the verdict.
        final warningsOnlyGateRefusal =
            failed != null &&
            idx == effectivePlan.steps.length - 1 &&
            effectivePlan.steps[idx].args.isNotEmpty &&
            effectivePlan.steps[idx].args.first == 'build' &&
            !(await _profileWarningsBlocking(cwd)) &&
            _isWarningsOnlyBuildGateRefusal(failed.output);
        if (warningsOnlyGateRefusal) {
          _logWarningsOnlyGateRefusal(failed.output);
        }
        // Issue #737: the plan's terminal `build` step validates the
        // WHOLE project (build_runner + analyze over the full tree), so
        // it can exit non-zero for reasons this behavior's generation
        // is not responsible for — e.g. a pre-existing red suite (the
        // pending U* stubs) or build-config noise. The pipeline
        // (FR-006) treats any non-zero exit as a plan failure; grading
        // that failure as `generation-error` is a false negative when
        // the generation steps themselves succeeded and the CURRENT
        // behavior's test passes. The guard is per-behavior BY
        // CONSTRUCTION: only the terminal `build` step qualifies (an
        // earlier failure means real generation work never ran), and
        // the behavior's own test must pass right now. Anything else
        // keeps the honest `generation-error` stop (safe-failure,
        // never a silent pass).
        final toleratedRun = warningsOnlyGateRefusal
            ? null
            : await _toleratedTerminalBuildFailure(
                runner: runner,
                plan: effectivePlan,
                result: pipelineResult,
                singleTemplate: singleTemplate,
                fileTemplate: fileTemplate,
                testPath: testPath,
                testName: testName,
                workingDirectory: cwd,
              );
        if (toleratedRun != null) {
          print(
            '   terminal build step failed: `${failed!.command}` '
            '(exit ${failed.exitCode}).',
          );
          print(
            "   per-behavior check: the behavior's own test passes — the "
            'build failure is not attributable to this make (issue #737 '
            'per-behavior guard); recording it as green-with-failed-build '
            '(issue #942).',
          );
          // Issue #1530 (FR-008): the tolerated class must never be a
          // quiet default — surface the failed build's analyzer warnings
          // verbatim in the receipt so the drift is visible per step.
          _printToleratedBuildWarnings(failed.output);
          postRun = toleratedRun;
          buildStepTolerated = true;
        } else if (!warningsOnlyGateRefusal) {
          // Issue #1322: a failed BUILD step whose output carries the
          // missing-builder-dependency class is corrupt project state, not
          // generation noise — grade it with the distinct outcome naming
          // the package + the exact fix, NOT the generic generation-error.
          final missingBuilders = idx >= 0 && idx < effectivePlan.steps.length
              ? missingBuildersForBuildStep(
                  step: failed!,
                  stepArgs: effectivePlan.steps[idx].args,
                  projectRoot: cwd,
                )
              : null;
          if (missingBuilders != null) {
            print(
              BuilderDependencyPreflight.missingBuilderStopMessage(
                missing: missingBuilders,
                context: 'the make plan\'s `zfa build` step',
              ),
            );
            // Issue #1036: same failed-make contract as the
            // generation-error path — the certified-red subject shape
            // survives the failed make and the retry fails honestly.
            await _restoreSubjectIfMutated(
              subjectFile,
              subjectSnapshot,
              reason: 'the make stopped with a missing-builder-dependency',
            );
            _printSummary(
              behavior: record.behaviorId,
              outcome: MakeOutcome.missingBuilderDependency,
              feature: target.featureName,
            );
            exitCode = 1;
            return;
          }
          print(
            'zfa tdd make: generation step failed at index $idx'
            '${failed != null ? ' (${failed.purpose})' : ''}:',
          );
          if (failed != null) {
            print('   command: `${failed.command}`');
            print('   exit: ${failed.exitCode}');
            print('   output (tail):');
            final tail = failed.output.length > 800
                ? failed.output.substring(failed.output.length - 800)
                : failed.output;
            print(tail.split('\n').take(20).join('\n'));
          }
          // Issue #1036: the make stops with a failure outcome — restore
          // the subject so the certified-red shape survives the failed
          // make and the retry fails honestly. (The #737/#942-tolerated
          // path above keeps the generated implementation: that make
          // completes green-with-failed-build; the `regression` guard
          // below deliberately leaves generated source in place for
          // inspection.)
          await _restoreSubjectIfMutated(
            subjectFile,
            subjectSnapshot,
            reason: 'the make stopped with a generation-error',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.generationError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
      }

      // 8. Target test post-generation (FR-007). When the terminal
      //    build step was tolerated (issue #737) the per-behavior
      //    guard's passing run IS the post-generation target run.
      if (!buildStepTolerated) {
        postRun = await _runTargetTest(
          runner: runner,
          singleTemplate: singleTemplate,
          fileTemplate: fileTemplate,
          testPath: testPath,
          testName: testName,
          workingDirectory: cwd,
          timeout: timeoutOverride,
        );
        print('   target test exit: ${postRun.exitCode}');
        if (postRun.exitCode != 0) {
          print(
            'zfa tdd make: target test still fails after generation '
            '(exit ${postRun.exitCode}).',
          );
          // Issue #1323 (spec 991): diagnose the GENERATED `_argN()`
          // placeholder BEFORE the generic stop. A declared contract
          // param the writer cannot scalar-literalize emits the
          // placeholder helper; a still-failing red whose transcript
          // names that helper IS the designed hand-delta seam, and
          // grading it as a bare `generation-error` dead-ended the
          // two-cycle run with a stop output that never named the
          // remedy (it only existed inside a thrown exception message
          // mid-test-output). Two signals must agree (FR-001): the
          // test file carries the marker helper AND the transcript
          // carries the message token — an unrelated red keeps the
          // honest generic stop.
          final handDelta = await _argPlaceholderDiagnosis(
            testPath: testPath,
            runOutput: postRun.output,
          );
          if (handDelta != null) {
            final relativeTest = p.isAbsolute(testPath)
                ? p.relative(testPath, from: cwd)
                : testPath;
            final remedy = argPlaceholderRemedy(
              index: handDelta.index,
              testPath: relativeTest.replaceAll('\\', '/'),
              declaredType: handDelta.declaredType,
              behaviorId: record.behaviorId,
            );
            print(
              'zfa tdd make: the failure is the GENERATED '
              "_arg${handDelta.index}() placeholder for a non-scalar "
              'declared param (issue #1323).',
            );
            print('   --> fix: $remedy.');
            print(
              '   the placeholder is the designed hand-delta seam: apply '
              'the edit to the generated test, then re-run make — the '
              're-run re-verifies the updated test before generating '
              '(the drift check, FR-005) and certifies the cycle from '
              'it.',
            );
            // The failed-make contract holds for the seam too (issue
            // #1036): the certified-red subject shape survives
            // untouched.
            await _restoreSubjectIfMutated(
              subjectFile,
              subjectSnapshot,
              reason: 'the make stopped with a hand-delta-required',
            );
            _printSummary(
              behavior: record.behaviorId,
              outcome: MakeOutcome.handDeltaRequired,
              feature: target.featureName,
            );
            exitCode = 1;
            return;
          }
          // Issue #1036: same failed-make contract as the step-failure
          // path — the certified-red subject shape survives untouched.
          await _restoreSubjectIfMutated(
            subjectFile,
            subjectSnapshot,
            reason: 'the make stopped with a generation-error',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.generationError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
      }
    }

    // ---------------------------------------------------------------
    // 9. Suite guard (FR-007, US3). Issue #741: the skip transition
    //    runs no guard (nothing was generated, so no NEW failure is
    //    attributable to this make); with a run-cached baseline the
    //    guard is certified from the scoped single-test result, falling
    //    back to the live full-suite guard only when that transcript is
    //    unusable (safe failure — never a silent pass).
    // ---------------------------------------------------------------
    SuiteSnapshot? guardSnap;
    var regressed = const <String>[];
    if (!alreadyGreen) {
      if (baselineFromCache) {
        final scopedGuard = guard.parse(
          command: postRun.command,
          exitCode: postRun.exitCode,
          output: postRun.output,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        if (scopedGuard.parseable) {
          print(
            '   suite guard: scoped single-test result (issue #741 '
            'baseline cache)',
          );
          guardSnap = scopedGuard;
        } else {
          print(
            '   scoped guard transcript unusable — falling back to the '
            'live suite',
          );
        }
      }
      if (guardSnap == null) {
        final guardRun = await runner.runSuite(
          suiteTemplate: suiteTemplate,
          workingDirectory: cwd,
          timeout: timeoutOverride,
        );
        final liveGuard = guard.fromRunRecord(
          record: guardRun,
          capturedAt: DateTime.now().toUtc().toIso8601String(),
        );
        if (!guardRun.startedProcess ||
            !liveGuard.parseable ||
            liveGuard.exitCode != 0 && liveGuard.failedTests.isEmpty) {
          print(
            'zfa tdd make: cannot parse the suite output to identify failing '
            'tests. Refusing to certify — the suite guard is a safe-failure '
            '(never a silent pass).',
          );
          _printSummary(
            behavior: record.behaviorId,
            outcome: MakeOutcome.runnerError,
            feature: target.featureName,
          );
          exitCode = 1;
          return;
        }
        guardSnap = liveGuard;
      }
      final baselineSnapshot = baseline!;
      final diff = guard.diff(baseline: baselineSnapshot, guard: guardSnap);
      // Issue #731: scope the regression verdict to failures THIS make
      // could have caused. The name-diff alone false-positives when the
      // suite already carries pre-existing red behaviors (e.g. deferred
      // acceptance tests): a red test's failing-test IDENTIFIER may vary
      // between the baseline and guard runs (dynamic test names), so the
      // guard sees a "new" failure that is really the same pre-existing
      // red behavior — and an already-green target's make reported
      // `regression` instead of `skipped`, deadlocking `tdd run`.
      regressed = _regressionsAttributableToThisMake(
        baseline: baselineSnapshot,
        newFailures: diff.newFailures,
        testPath: testPath,
      );
      if (regressed.length < diff.newFailures.length) {
        final tolerated = diff.newFailures
            .where((id) => !regressed.contains(id))
            .toList();
        print(
          '   suite guard: ${tolerated.length} failing id(s) belong to files '
          'already red at baseline — pre-existing red behaviors, tolerated '
          '(issue #731):',
        );
        for (final id in tolerated) {
          print('   - $id');
        }
      }
      if (regressed.isNotEmpty) {
        print(
          'zfa tdd make: regression detected — ${regressed.length} '
          'NEW failure(s) introduced by the generation:',
        );
        for (final id in regressed) {
          print('   - $id');
        }
        print('   generated source left in place for inspection.');
        _printSummary(
          behavior: record.behaviorId,
          outcome: MakeOutcome.regression,
          feature: target.featureName,
        );
        exitCode = 1;
        return;
      }
    }

    // ---------------------------------------------------------------
    // 10. Green evidence append (FR-008). For the issue #694 skip
    //     transition the generation block is explicitly empty and the
    //     evidence command is the drift re-run. Issue #741: on the skip
    //     transition no suite ran, so the suite numbers record the
    //     honest zeros (nothing generated → no suite risk taken); with
    //     a run-cached baseline the baseline number is the cached
    //     snapshot's and the guard number is the scoped single-test
    //     result's. Every number is real, from the run that produced it.
    // ---------------------------------------------------------------
    final log = CycleLog(target.featureDir);
    await log.append(
      CycleLogEntry(
        behaviorId: record.behaviorId,
        kind: CycleEntryKind.green,
        runnerCommand: postRun.command,
        exitCode: postRun.exitCode,
        capturedOutput: postRun.output,
        sourceCriterion: record.sourceCriterion,
        testPath: record.testPath,
        timestamp: DateTime.now().toUtc().toIso8601String(),
        subjectHash: await _subjectHashAt(cwd, record),
        generationSteps: pipelineResult?.steps ?? const [],
        suiteBaselineFailures: baseline?.failedTests.length ?? 0,
        suiteGuardFailures: guardSnap?.failedTests.length ?? 0,
        suiteNewFailures: regressed,
      ),
    );
    // Issue #969 T003: the green evidence becomes self-certifying.
    await TddGenerationReceipts.writeBestEffort(
      projectRoot: cwd,
      command: 'tdd make',
      target: record.behaviorId,
      feature: target.featureName,
      files: {p.join(target.featureDir, 'tdd', 'cycle-log.md'): 'update'},
    );
    print(
      '   green evidence appended to ${TddFeaturePaths.displayDir(cwd: cwd, dir: target.featureDir)}/tdd/'
      'cycle-log.md',
    );
    _printSummary(
      behavior: record.behaviorId,
      outcome: buildStepTolerated
          ? MakeOutcome.greenWithFailedBuild
          : alreadyGreen
          ? (adoptedReDrive ? MakeOutcome.adopted : MakeOutcome.skipped)
          : placeholderReDrive
          ? MakeOutcome.adoptedPlaceholder
          : MakeOutcome.green,
      feature: target.featureName,
    );
    exitCode = 0;
  }

  // -------------------------------------------------------------------
  // Helpers — resolution + summary (mirror verify_red_command.dart).
  // -------------------------------------------------------------------

  /// The loop kind the feature's test-list row declares for
  /// [behaviorId] (bug #835), or null when the list is unreadable or the
  /// row is missing — null keeps the pre-#835 kindless routing for every
  /// legacy list. A malformed list prints a note (it is a real problem,
  /// but the kind is only an optimization over the id dispatch and other
  /// steps re-surface the malformation honestly).
  ///
  /// Issue #939: widget rows resolve as WIDGET here (the shared
  /// `TestListReader` contract parses the `## Outer loop: widget
  /// behaviors` header since bug #830) — the kind the composition
  /// fallback's widget lane and the discovery gate now consume. The
  /// pre-#939 disengage message hardcoded "is unit-kind" for every
  /// non-acceptance kind and mislabeled exactly this resolution.
  Future<BehaviorKind?> _rowKind(String featureDir, String behaviorId) async {
    try {
      for (final row in await TestListReader(featureDir).read()) {
        if (row.id == behaviorId) return row.kind;
      }
    } on TestListReadException catch (e) {
      print(
        '   note: test list unreadable ( ${e.message}) — '
        'routing on id/description only',
      );
    }
    return null;
  }

  /// The row kind WITHOUT the unreadable-list note: the vacuous-green
  /// preflight (issue #1259) runs on every make — including legacy
  /// fixtures whose project carries no test list — and a note there
  /// would be noise on every legacy run. Kindless (no list, unreadable,
  /// row missing) fails open: no refusal.
  Future<BehaviorKind?> _rowKindQuiet(
    String featureDir,
    String behaviorId,
  ) async {
    final listFile = File(p.join(featureDir, 'tdd', 'test-list.md'));
    if (!await listFile.exists()) return null;
    try {
      for (final row in await TestListReader(featureDir).read()) {
        if (row.id == behaviorId) return row.kind;
      }
    } on TestListReadException {
      return null;
    }
    return null;
  }

  /// Feature 071: the behavior's raw trace tokens from its test-list
  /// row (`traces:` cell) — the resolver resolves these against
  /// declared contract rows. Empty when the row is missing. Tokens are
  /// split by [SpecParser.traceTokens], so a backticked inline
  /// signature never splits mid-declaration and signature-shaped
  /// tokens never dangle (round-2 review fix 2).
  Future<List<String>> _rowTraces(String featureDir, String behaviorId) async {
    try {
      for (final row in await TestListReader(featureDir).read()) {
        if (row.id != behaviorId) continue;
        return SpecParser.traceTokens(row.traces);
      }
    } on TestListReadException {
      // unreadable list: kindless/traceless routing, as pre-#835
    }
    return const [];
  }

  /// Feature 071: the spec's parsed routing declarations (markers,
  /// contract rows, persistence). A MISSING or UNREADABLE spec yields
  /// EMPTY declarations — the resolver still runs, so under
  /// --strict-routing everything is honestly undeclared (refusal), and
  /// in the fallback window the legacy branches route unchanged. A
  /// MALFORMED spec (the parser's StateError refusals) propagates to
  /// the caller (round-2 review fix 3b): swallowing it would route a
  /// declared behavior on legacy prose — the #920 regression class.
  Future<SpecDeclarations> _declarationsFor(String featureDir) async {
    final specFile = File('$featureDir/spec.md');
    if (!specFile.existsSync()) return const SpecDeclarations();
    final String specMd;
    try {
      specMd = specFile.readAsStringSync();
    } on FileSystemException {
      return const SpecDeclarations(); // unreadable file: empty declarations
    }
    return SpecDeclarations(
      scenarios: SpecParser.parseScenarioTypeMarkers(specMd),
      // Issue #1485: the declared rows include the feature's
      // contracts/*.md rows — a trace bound at plan time resolves its
      // declared signature at gen time (declare once, resolve
      // everywhere). The resolver's API is unchanged.
      contractRows: SpecParser.declaredContractRows(
        specMd,
        contractFiles: DeclaredRouting.contractFiles(featureDir),
      ).rows,
      persistence: SpecParser.parsePersistenceDeclarations(specMd),
    );
  }

  /// The composition fallback for an unexpressible plan (issue #642, spec
  /// 052). Returns the composition plan (`compose <id>` → `build`) when
  /// the fallback engages, or null when the honest `unexpressible` stop
  /// stands:
  ///
  /// - the behavior has no test-list row, or the list is unreadable —
  ///   fail-closed (the fallback never guesses kinds);
  /// - the row is unit-kind (a unit subject implements its own logic);
  /// - the feature has zero composable green unit subjects (nothing to
  ///   wire against — the acceptance prose remains uncomposable).
  ///
  /// Issue #939 — the WIDGET lane engages BEFORE all of the above: a
  /// widget-kind row's make path is the deterministic view-builder
  /// generation (`tdd view <id>` → `build`), shaped without anchor
  /// discovery because the minimal view is driven by the spec's declared
  /// Presentation layer contract + the behavior's scenario literals, not
  /// by the feature's green unit subjects (no anchor precondition — the
  /// loop must reach green through a generated skeleton exactly as func
  /// subjects do). Scenario-specific behavior inside the emitted view
  /// stays the sanctioned handcraft seam.
  ///
  /// The fallback shapes the acceptance plan through the pure
  /// `CompositionPlanner`; the planner itself (FR-008, SC-006) stays
  /// untouched and unaware of phases, run state, or subjects.
  Future<GenerationPlan?> _compositionFallback({
    required String cwd,
    required ArtifactRecord record,
    required String featureDir,
    required String featureName,
    // Issue #1471: the canonical reference a spawned child re-resolves —
    // for a bug directory this is `.specify/bugs/<slug>`, never the plain
    // slug (which would resolve to `specs/<slug>`). Non-nullable: the only
    // call site passes `featureRef ?? target.featureName`, and
    // `target.featureName` is itself non-nullable.
    required String featureRef,
    required BehaviorSummary summary,
  }) async {
    // Issue #939 — the widget lane: a widget-kind target's make path is
    // the deterministic view-builder generation, shaped BEFORE anchor
    // discovery. The minimal view is driven by the spec's declared
    // Presentation layer contract + the behavior's scenario literals
    // (the same finders the paired widget test asserts), not by the
    // feature's green unit subjects, so no anchor precondition applies
    // (unlike the acceptance composition below). The generation step is
    // `zfa tdd view <id>` (registered alongside func/compose); the
    // composition gate's kind fix (widget treated like acceptance,
    // issue #939) governs the shared discovery surface for direct
    // `zfa tdd compose` callers.
    if (summary.kind == BehaviorKind.widget) {
      print(
        '   widget lane: view-builder generation (issue #939) — '
        'deterministic minimal view from the declared Presentation '
        'contract',
      );
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          GenerationStepSpec(
            args: [
              'tdd',
              'view',
              summary.behaviorId,
              '--feature',
              // Issue #1471: hand the child the reference that resolves to
              // the REAL feature directory (a plain name for a specs
              // feature, `.specify/bugs/<slug>` for a bug directory).
              featureRef,
            ],
            purpose:
                'generate the minimal view for behavior '
                '${summary.behaviorId} from the declared Presentation '
                'layer contract (issue #939)',
          ),
          GenerationStepSpec(
            args: ['build'],
            purpose: 'build generated code for behavior ${summary.behaviorId}',
          ),
        ],
      );
    }
    final discovery = await const CompositionTargets().discover(
      projectRoot: cwd,
      featureDir: featureDir,
      behaviorId: record.behaviorId,
      // Issue #1162: bug features may compose against stub-only unit
      // subjects — the bug extension's sanctioned path from a prose
      // scenario's unexpressible plan to green. Non-bug features keep
      // the strict no-green-units stop (unchanged).
      allowStubAnchors: CompositionTargets.isBugFeatureDir(featureDir),
    );
    if (discovery is CompositionTargetFailure) {
      // Fail-closed: name the disengagement reason, keep the honest stop.
      print('   composition fallback disengaged: ${discovery.message}');
      return null;
    }
    final anchors = (discovery as CompositionTargetResolved).anchors;
    // Issue #923: the anchors may mix green subjects with entity-wired
    // stubs — name both so the fallback's report stays honest. Issue
    // #1162: they may also include stub-only subjects (bug features).
    final wiredCount = anchors.where((a) => a.entityWired).length;
    final stubCount = anchors.where((a) => a.stubOnly).length;
    final greenCount = anchors.length - wiredCount - stubCount;
    final anchorSummary =
        '${greenCount > 0 ? '$greenCount green' : ''}'
        '${wiredCount > 0 ? '${greenCount > 0 ? ', ' : ''}$wiredCount entity-wired' : ''}'
        '${stubCount > 0 ? '${greenCount > 0 || wiredCount > 0 ? ', ' : ''}$stubCount stub-only' : ''}'
        ' unit subject(s)';
    print(
      '   composition fallback: $anchorSummary '
      '(${anchors.map((a) => a.behaviorId).join(', ')})',
    );
    return const CompositionPlanner().plan(summary, anchors);
  }

  // -------------------------------------------------------------------
  // Per-behavior guard for the make plan's terminal build step
  // (issue #737).
  // -------------------------------------------------------------------

  /// The per-behavior guard for the make plan's terminal `build` step
  /// (issue #737). Returns the passing target-test [RunRecord] when the
  /// tolerance engages, null otherwise (the honest `generation-error`
  /// stop stands).
  ///
  /// The plan's terminal `build` step validates the WHOLE project, so
  /// its non-zero exit can reflect pre-existing red suite state or
  /// build-config noise rather than this behavior's generation. The
  /// tolerance engages only when ALL of the following hold:
  ///
  ///   - the pipeline failed at the plan's TERMINAL step (an earlier
  ///     failure means real generation work never ran — no tolerance);
  ///   - that step is a `build` step (the #737 scope: the make plan's
  ///     build/guard logic only);
  ///   - the failed step's output carries NO analyzer ERRORS (issue
  ///     #942): `dart analyze` error lines mean the generated tree does
  ///     not compile — the behavior test can pass only because nothing
  ///     exercises the broken files. Tolerating that would green-wash
  ///     the make; the honest stop stands instead;
  ///   - the CURRENT behavior's own test — the profile `single`
  ///     command, e.g. `dart test test/tdd/u3_test.dart` — runs and
  ///     passes right now (the same per-behavior check the TDD loop is
  ///     built on; it also compiles the scaffolded subject, so broken
  ///     generated code still fails here).
  ///
  /// Anything else (launch failure, red target test, non-build step)
  /// returns null: safe-failure, never a silent pass.
  Future<RunRecord?> _toleratedTerminalBuildFailure({
    required SingleTestRunner runner,
    required GenerationPlan plan,
    required PipelineResult result,
    required String singleTemplate,
    String? fileTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
  }) async {
    final idx = result.firstFailureIndex;
    if (idx < 0 || idx != plan.steps.length - 1) return null;
    final args = plan.steps[idx].args;
    if (args.isEmpty || args.first != 'build') return null;
    // Issue #942: a failed build whose analyze stage reports ERRORS is
    // not tolerable noise — the generated tree does not compile. The
    // behavior's own test passing proves nothing here (nothing may
    // exercise the broken files), so the tolerance must refuse and keep
    // the honest `generation-error` stop. Warnings/info/build-config
    // noise still tolerable (the #737 scope).
    final buildOutput = result.steps[idx].output;
    if (BuildCommand.analyzeReportsError(buildOutput)) {
      final errorLines = BuildCommand.countAnalyzerErrors(buildOutput);
      print(
        '   terminal build step failed with $errorLines analyzer error(s) '
        '— a non-compiling generated tree is not tolerable noise '
        '(issue #942): the per-behavior guard refuses the tolerance.',
      );
      return null;
    }
    final run = await _runTargetTest(
      runner: runner,
      singleTemplate: singleTemplate,
      fileTemplate: fileTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: workingDirectory,
    );
    if (!run.startedProcess || run.exitCode != 0) return null;
    return run;
  }

  // -------------------------------------------------------------------
  // Errors-only analyze gate (issue #1407): helpers for the make's
  // interpretation of the terminal build step's analyze verdict.
  // -------------------------------------------------------------------

  /// The build command's analyze-gate refusal verdict (issue #1407). The
  /// message has exactly ONE writer — the build command's post-build
  /// analyze gate (issues #395/#1035):
  /// `❌ dart analyze reported <E> error(s) and <W> warning(s) — generated
  /// code does not compile cleanly.` — and carries the counts the gate
  /// decided on. Reading the verdict from the gate's own line is what
  /// keeps this an interpretation fix: the dart analyze invocation, the
  /// build command, and everything the analyzer reports are unchanged.
  static final RegExp _analyzeGateRefusalPattern = RegExp(
    r'dart analyze reported (\d+) error\(s\) and (\d+) warning\(s\)',
  );

  /// Issue #1407: whether [buildOutput] is the build command's
  /// analyze-gate refusal on WARNINGS ONLY — 0 error(s) and at least one
  /// warning — i.e. the tree compiles (0 errors) and the build step
  /// failed only because the #1035 gate treats warnings as fatal.
  ///
  /// Requires BOTH of:
  ///
  ///   - the gate's own refusal message naming 0 errors (the single
  ///     writer documented on [_analyzeGateRefusalPattern]). A build
  ///     failure without that message is some other failure class
  ///     (build_runner, DDA routes, post-build verifiers) and keeps the
  ///     existing #737/#942/#1322 grading unchanged;
  ///   - the shared analyzer line-format parser
  ///     ([BuildCommand.countAnalyzerIssues], the #1035 single contract)
  ///     finds NO `error -` lines in the raw output. If the gate message
  ///     and the parser disagree, the honest stop stands (safe-failure,
  ///     never a silent pass).
  static bool _isWarningsOnlyBuildGateRefusal(String buildOutput) {
    final match = _analyzeGateRefusalPattern.firstMatch(buildOutput);
    if (match == null) return false;
    final errors = int.tryParse(match.group(1)!) ?? -1;
    final warnings = int.tryParse(match.group(2)!) ?? -1;
    if (errors != 0 || warnings < 1) return false;
    return !BuildCommand.analyzeReportsError(buildOutput);
  }

  /// Issue #1407 (FR-002): log the warnings-only gate refusal — the
  /// verdict line naming the counts and the errors-only policy, then the
  /// analyzer `warning -` lines. A voluminous verdict logs a capped
  /// sample plus a remainder count so the transcript stays readable.
  static void _logWarningsOnlyGateRefusal(String buildOutput) {
    final match = _analyzeGateRefusalPattern.firstMatch(buildOutput)!;
    final warnings = int.parse(match.group(2)!);
    print(
      '   analyze gate: 0 error(s), $warnings warning(s) — warnings are '
      'non-blocking (issue #1407, errors-only gate): the make proceeds.',
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

  /// Issue #1530 (FR-008): the `green-with-failed-build` receipt's
  /// warnings block — the tolerated class is never a quiet default.
  /// Prints the analyzer `warning -` lines from the failed build output
  /// verbatim (the #1407 presentation contract: a capped sample plus a
  /// remainder count so the transcript stays readable), or an explicit
  /// no-warnings line when the output carries none (the build failed
  /// for another reason). Print-only: the #942/#737 grading that chose
  /// this path is untouched.
  static void _printToleratedBuildWarnings(String buildOutput) {
    final warningLines = RegExp(
      r'^\s*warning\s*-\s.*$',
      multiLine: true,
    ).allMatches(buildOutput).map((m) => m.group(0)!.trim()).toList();
    if (warningLines.isEmpty) {
      print(
        '   no analyzer warnings reported — the build failed for '
        'another reason (see output above).',
      );
      return;
    }
    print(
      '   analyzer warnings in the failed build output (verbatim):',
    );
    const maxLogged = 10;
    for (final line in warningLines.take(maxLogged)) {
      print('   $line');
    }
    final remainder = warningLines.length - maxLogged;
    if (remainder > 0) {
      print('   ... $remainder more warning(s)');
    }
  }

  /// Issue #1407 (FR-005): whether the project opted into the LEGACY
  /// warnings-blocking strictness via the TDD profile's machine-readable
  /// Keys block (`analyze-gate: warnings-blocking`). The default — absent
  /// key, an explicit `analyze-gate: errors-only`, an unrecognized value,
  /// or a missing/unreadable profile — is errors-only (fail-open to the
  /// fix, never to the legacy refusal). Resolution order mirrors
  /// [SingleTestRunner.loadSingleTemplate]: the Keys block first, then
  /// the legacy frontmatter block.
  Future<bool> _profileWarningsBlocking(String workingDirectory) async {
    final file = File(
      p.join(workingDirectory, SingleTestRunner.defaultProfilePath),
    );
    if (!await file.exists()) return false;
    final String raw;
    try {
      raw = await file.readAsString();
    } catch (_) {
      return false;
    }
    String? value;
    final keysBlock = RegExp(
      r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(raw);
    if (keysBlock != null) {
      value = _profileGateValue(keysBlock.group(1)!);
    }
    value ??= () {
      final frontmatter = RegExp(
        r'^---\n([\s\S]*?)\n---',
        dotAll: true,
      ).firstMatch(raw);
      return frontmatter == null
          ? null
          : _profileGateValue(frontmatter.group(1)!);
    }();
    return value?.trim().toLowerCase() == 'warnings-blocking';
  }

  /// The `analyze-gate:` scalar in one profile yaml block, or null when
  /// the block does not carry the key. Quoted scalars are unwrapped —
  /// the same three-group shape [SingleTestRunner] uses for every
  /// profile value (the profile canonically quotes its keys).
  static String? _profileGateValue(String block) {
    final match = RegExp(
      r'''^\s*analyze-gate:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+))''',
      multiLine: true,
    ).firstMatch(block);
    if (match == null) return null;
    for (var i = 1; i <= match.groupCount; i++) {
      final g = match.group(i);
      if (g != null && g.isNotEmpty) return g;
    }
    return null;
  }

  /// The issue #1402 targeted remedy (the issue's minimum expected fix):
  /// the exact sentence an agent hand-driving the cycle needs.
  static const String _plainNameRemedy =
      '   --> fix: test name must contain the behavior description '
      'verbatim — rename the test(...) to embed it (issue #1402).';

  /// package:test's exit code when the runner executed zero tests
  /// (`--plain-name` / `--name` matched nothing) — issue #1402.
  static const int _exitCodeNoTests = 79;

  /// The runner's no-tests signature (issue #1402): `dart test` /
  /// `flutter test` exit 79 with a "No tests ran." transcript when the
  /// `--plain-name` filter matched zero tests.
  ///
  /// Scoped to the make command's own target-test invocations — the
  /// `--plain-name` flag semantics and the verify-red logic are untouched.
  static bool _noTestsRan(RunRecord run) =>
      run.startedProcess &&
      run.exitCode == _exitCodeNoTests &&
      run.output.contains('No tests ran');

  /// Run the behavior's target test through the profile `single` template
  /// with the issue #1402 zero-match guard.
  ///
  /// `--plain-name` is a literal SUBSTRING match against the OUTER
  /// test(...) name; a hand-edited test whose name no longer embeds the
  /// behavior description verbatim matches ZERO tests, the runner exits
  /// 79 ("No tests ran"), and the transcript proves nothing about the
  /// behavior. Left alone, the drift check grades the phantom as "still
  /// red" and spends generation the post-run can never observe — the
  /// issue's silent exit-79 dead-end.
  ///
  /// When the single run carries the zero-match signature (only for a
  /// template that actually carries `--plain-name`):
  ///   1. WARN — name the mismatch and the exact resolved command;
  ///   2. fall back to the WHOLE target file through the profile's `file:`
  ///      template so the caller grades real evidence (the drift check
  ///      then re-certifies red/green from an honest transcript);
  ///   3. when the fallback is unavailable (no `file:` template) or ALSO
  ///      runs zero tests, emit the targeted remedy and return the
  ///      ORIGINAL zero-match record — callers keep today's honest
  ///      grading, now with the diagnosis printed.
  Future<RunRecord> _runTargetTest({
    required SingleTestRunner runner,
    required String singleTemplate,
    String? fileTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
    Duration? timeout,
  }) async {
    final run = await runner.runSingle(
      singleTemplate: singleTemplate,
      testPath: testPath,
      testName: testName,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
    if (!singleTemplate.contains('--plain-name') || !_noTestsRan(run)) {
      return run;
    }
    final display = singleTemplate
        .replaceAll('{file}', testPath)
        .replaceAll('{name}', testName);
    print(
      '   issue #1402: --plain-name matched ZERO tests — the outer '
      'test(...) name does not contain the behavior description verbatim '
      '(command: `$display`).',
    );
    final fallback = fileTemplate;
    if (fallback == null || fallback.trim().isEmpty) {
      print(_plainNameRemedy);
      return run;
    }
    final resolvedFallback = fallback
        .replaceAll('{file}', testPath)
        .replaceAll('{name}', testName);
    print('   falling back to the whole target file: $resolvedFallback');
    final fileRun = await runner.runSingle(
      singleTemplate: fallback,
      testPath: testPath,
      testName: testName,
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
    if (!fileRun.startedProcess) {
      print(
        '   the whole-file fallback did not start (`$resolvedFallback`): '
        '${fileRun.output}',
      );
      print(_plainNameRemedy);
      return run;
    }
    if (_noTestsRan(fileRun)) {
      print(_plainNameRemedy);
      return run;
    }
    return fileRun;
  }

  /// The missing-builder-dependency classifier for a failed plan step
  /// (issue #1322). Returns the missing builder registrations when ALL of
  /// the following hold, null otherwise (the caller keeps the existing
  /// grading):
  ///
  ///   - the failed step IS a plan `build` step ([stepArgs] starts with
  ///     `build`) — only build failures can carry the missing-builder
  ///     class;
  ///   - the step actually failed (non-zero exit);
  ///   - the shared classifier diagnoses a builder registered in
  ///     build.yaml whose package is not resolvable in
  ///     `.dart_tool/package_config.json` (corroborated by build_runner's
  ///     unknown-builder signal in the captured step output).
  @visibleForTesting
  static List<RegisteredBuilder>? missingBuildersForBuildStep({
    required GenerationStep step,
    required List<String> stepArgs,
    required String projectRoot,
  }) {
    if (stepArgs.isEmpty || stepArgs.first != 'build') return null;
    if (step.exitCode == 0) return null;
    final missing = BuilderDependencyPreflight.missingBuildersForFailedBuild(
      projectRoot: projectRoot,
      buildOutput: step.output,
    );
    return missing.isEmpty ? null : missing;
  }

  /// The behavior description the planner will see — the record's own
  /// parsing contract ([ArtifactRecord.descriptionSegment]): the
  /// description segment with any legacy `<id> — ` echo stripped
  /// (bug #871). Issue #873: stripping is canonical so the planner
  /// never reads the behavior's own id as an entity name.
  String _descriptionFor(ArtifactRecord record) => record.descriptionSegment;

  /// The target name parsed from the runnable name's description
  /// segment. For entity-bearing descriptions like "create entity
  /// User with email" the planner derives the entity name itself.
  String? _targetFor(ArtifactRecord record) {
    final desc = _descriptionFor(record);
    // For behaviors whose description names a target, return it.
    // Otherwise null and let the planner decide.
    final m = RegExp(r'entity\s+([A-Z][A-Za-z0-9_]*)').firstMatch(desc);
    if (m != null) return m.group(1);
    return null;
  }

  /// The runnable test name for `--plain-name` matching — the record's
  /// own contract ([ArtifactRecord.plainTestName]): the last segment with
  /// any legacy `<id> — ` echo stripped (bug #871), so both the legacy
  /// and the re-rendered test-file shapes substring-match.
  String _runnableNameOf(ArtifactRecord record) => record.plainTestName;

  /// The skip transition's subject-identity check (issue #1036): returns
  /// the refusal message when the subject file's CURRENT shape does not
  /// match the shape the certified evidence captured, or null when the
  /// skip may proceed.
  ///
  /// The rule:
  ///   - a certified GREEN entry with a subject hash is authoritative —
  ///     the current subject must match it (an honest #694 re-run after
  ///     a certified make has the same subject; unit skip semantics are
  ///     unchanged);
  ///   - with no green entry (the #1036 bug state), the certified RED
  ///     entry's subject hash is authoritative — a subject a failed make
  ///     rewrote to a placeholder can never take the skip. Issue #1162:
  ///     the red-basis rule FAILS OPEN when the drifted subject is a real
  ///     hand implementation ([_acceptImplementedSubjectDrift]) — the
  ///     gen'd test header's own sanctioned transition — so a bug subject
  ///     can certify green; the born-green placeholder classes
  ///     ([subjectIsBornGreenPlaceholder]) keep refusing;
  ///   - hashless entries (legacy logs, or runs with no subject
  ///     artifact) fail open — the pre-#1036 behavior stands — so
  ///     existing logs and fixtures keep skipping exactly as before.
  Future<String?> _subjectDriftRefusal(
    String cwd,
    String featureDir,
    ArtifactRecord record,
  ) async {
    final currentHash = await _subjectHashAt(cwd, record);
    if (currentHash == null) return null; // no subject artifact to verify
    final evidence = CycleEvidence(featureDir);
    final lastGreen = await evidence.lastEntryFor(
      record.behaviorId,
      kind: 'green',
    );
    final lastRed = await evidence.lastEntryFor(record.behaviorId, kind: 'red');
    final String? certified;
    final String basis;
    if (lastGreen?.subjectHash != null) {
      certified = lastGreen!.subjectHash;
      basis = 'certified green evidence';
    } else if (lastRed?.subjectHash != null) {
      certified = lastRed!.subjectHash;
      basis = 'certified red evidence';
    } else {
      return null; // legacy hashless evidence — fail open (pre-#1036)
    }
    if (currentHash == certified) return null;
    // Issue #1430: the loop's own refactor pass re-proves the suite green
    // over a rewritten certified subject and appends a `refresh` entry
    // re-binding the certified shape to the post-rewrite bytes. Accept the
    // drift the loop itself produced: the behavior's LAST refresh entry
    // matching the CURRENT subject, not older than the certified basis
    // entry (ISO-8601; unparseable or missing timestamps fail closed — the
    // refusal stands), proves the current shape is the re-proved one. An
    // out-of-band edit after the refresh changes the hash and keeps the
    // refusal, so the guard never widens beyond the loop's own rewrite.
    final lastRefresh = await evidence.lastEntryFor(
      record.behaviorId,
      kind: 'refresh',
    );
    if (lastRefresh?.subjectHash != null &&
        lastRefresh!.subjectHash == currentHash &&
        (lastRefresh.exit ?? 1) == 0) {
      final refreshedAt = DateTime.tryParse(lastRefresh.at ?? '');
      final basisAt = DateTime.tryParse(
        (lastGreen?.subjectHash != null ? lastGreen!.at : lastRed?.at) ?? '',
      );
      if (refreshedAt != null &&
          basisAt != null &&
          !refreshedAt.isBefore(basisAt)) {
        print(
          '   subject drift accepted (issue #1430): the current subject '
          "shape is the one the loop's refactor pass re-proved green "
          '(refresh evidence at ${lastRefresh.at}) — the certified '
          'evidence re-binds to it.',
        );
        return null;
      }
    }
    // Issue #1162: a red-basis drift is the hand-implementation
    // transition when the subject is not a born-green placeholder — the
    // drift check just proved the target test passes with its scenario
    // assertions genuinely executing. Fail open; the skip transition's
    // green evidence re-binds to the current subject shape. A green-basis
    // drift (a post-green rewrite) and every placeholder class keep the
    // refusal.
    if (lastGreen?.subjectHash == null && lastRed != null) {
      if (await _acceptImplementedSubjectDrift(cwd, record)) return null;
    }
    final subjectPath = p.isAbsolute(record.subjectPath)
        ? record.subjectPath
        : p.join(cwd, record.subjectPath);
    return 'zfa tdd make: behavior "${record.behaviorId}" — the target '
        'test already passes, but the subject file at $subjectPath no '
        'longer matches the shape the $basis captured (issue #1036): a '
        'skip here would certify green on a subject the red evidence '
        'never exercised — the born-green placeholder class.\n'
        '   $basis subject-hash: $certified\n'
        '   current subject-hash: $currentHash\n'
        '--> fix: restore the subject to its certified shape '
        '(git checkout $subjectPath), or — when the subject was '
        'hand-implemented and the passing test genuinely exercises it — '
        're-certify the transition with `zfa tdd verify-red '
        '${record.behaviorId} --re-certify` (issue #1162), then re-run '
        'make.';
  }

  /// Issue #1331: whether [record] is the complete-but-unowned re-drive
  /// class — the behavior is tombstoned by the feature's LAST reset AND
  /// its surviving green evidence predates that tombstone (or there is
  /// none left at all). The tombstone is the user's explicit "drop the
  /// certification and start over": the certified-hash basis the #1036
  /// guard compares against is stale by decree, and the re-drive's make
  /// sees exactly the state the first drive saw.
  ///
  /// Fail-closed: an absent journal, a corrupt one, an unparseable
  /// tombstone timestamp, or an unparseable evidence timestamp returns
  /// false — the #1036 refusal then stands exactly as before.
  Future<bool> _tombstonedReDrive(
    String featureDir,
    ArtifactRecord record,
  ) async {
    final tombstone = await JournalReader.lastResetTombstone(featureDir);
    final tombstoneAt = tombstone.at;
    if (tombstoneAt == null) return false;
    if (!tombstone.behaviors.contains(record.behaviorId)) return false;
    final lastGreen = await CycleEvidence(
      featureDir,
    ).lastEntryFor(record.behaviorId, kind: 'green');
    // No green entry left at all — the re-drive class stands.
    if (lastGreen == null) return true;
    // A PRESENT green entry whose timestamp is missing or unparseable
    // cannot prove it predates the tombstone — fail closed (the #1036
    // refusal stands exactly as before).
    final at = lastGreen.at;
    if (at == null || at.isEmpty) return false;
    final greenAt = DateTime.tryParse(at);
    if (greenAt == null) return false;
    return greenAt.isBefore(tombstoneAt);
  }

  /// Whether the behavior's subject file on disk is one of the
  /// born-green placeholder shapes (issue #1036) — the gate that keeps a
  /// tombstoned re-drive from adopting an empty scaffold into green.
  /// Unreadable subject files fail CLOSED (treated as a placeholder —
  /// the refusal stands), never silently adopted.
  Future<bool> _subjectIsBornGreenPlaceholderOnDisk(
    String cwd,
    ArtifactRecord record,
  ) async {
    final subjectPath = p.isAbsolute(record.subjectPath)
        ? record.subjectPath
        : p.join(cwd, record.subjectPath);
    try {
      return subjectIsBornGreenPlaceholder(
        await File(subjectPath).readAsString(),
      );
    } on FileSystemException {
      return true; // unreadable — keep the refusal (safe failure)
    }
  }

  /// Issue #1162: whether a red-basis drift is the SANCTIONED
  /// hand-implementation transition — the subject on disk is not one of
  /// the pipeline's born-green placeholder shapes, i.e. it was
  /// hand-implemented, exactly what the generated test header's own
  /// instruction produces ("Replace the subject's stub body with real
  /// implementation"). The drift check has already proven the target test
  /// passes right now: the scenario assertions the certified red
  /// exercised genuinely execute against the implemented subject, so the
  /// #694 skip transition may re-bind the green evidence to the new
  /// shape. The born-green classes (scaffolded marker, still-throwing
  /// stubs, the func-scaffold vacuous bodies — issue #1036) keep refusing
  /// via [subjectIsBornGreenPlaceholder].
  ///
  /// Returns true when the drift is ACCEPTED (the acceptance note is
  /// printed); false when the refusal stands (unreadable subject or a
  /// recognized placeholder shape — safe failure, never a silent pass).
  Future<bool> _acceptImplementedSubjectDrift(
    String cwd,
    ArtifactRecord record,
  ) async {
    final subjectPath = p.isAbsolute(record.subjectPath)
        ? record.subjectPath
        : p.join(cwd, record.subjectPath);
    String raw;
    try {
      raw = await File(subjectPath).readAsString();
    } on FileSystemException {
      return false; // unreadable subject — keep the refusal (safe failure)
    }
    if (subjectIsBornGreenPlaceholder(raw)) return false; // #1036 stands
    print(
      '   subject drift accepted (issue #1162): the target test passes '
      'with its scenario assertions genuinely executing against the '
      'hand-implemented subject (not a pipeline placeholder) — the skip '
      'transition re-binds the green evidence to the current subject '
      'shape.',
    );
    return true;
  }

  /// The sha256 of the behavior's subject file at certification time
  /// (issue #1036): binds green evidence to the EXACT subject shape it
  /// exercised. Null when the subject artifact is missing — the field is
  /// omitted and the skip validation fails open for that entry (legacy
  /// tolerance).
  Future<String?> _subjectHashAt(String cwd, ArtifactRecord record) async {
    final subjectPath = p.isAbsolute(record.subjectPath)
        ? record.subjectPath
        : p.join(cwd, record.subjectPath);
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) return null;
    return sha256.convert(await subjectFile.readAsBytes()).toString();
  }

  /// Issue #1323 (spec 991 FR-001): the two-signal `_argN()` placeholder
  /// diagnosis over the still-failing target run — the test file must
  /// carry the generated marker helper AND the transcript must carry the
  /// placeholder's message token. Unreadable test files (deleted between
  /// the run and this read, permission-denied) fail CLOSED — null, the
  /// generic stop stands — so a filesystem hiccup can never fabricate a
  /// hand-delta seam.
  Future<ArgPlaceholderHit?> _argPlaceholderDiagnosis({
    required String testPath,
    required String runOutput,
  }) async {
    try {
      final testContent = await File(testPath).readAsString();
      return argPlaceholderHitOf(
        testContent: testContent,
        runOutput: runOutput,
      );
    } on FileSystemException {
      return null;
    }
  }

  /// Issue #1036: a FAILED make must leave the subject file byte-identical
  /// to what it found — restore the pre-pipeline snapshot when a
  /// generation step mutated (or removed) it. The certified-red throwing
  /// stub then survives the failed make untouched, so the retry fails
  /// honestly instead of skipping green on a placeholder.
  Future<void> _restoreSubjectIfMutated(
    File subjectFile,
    String? snapshot, {
    required String reason,
  }) async {
    if (snapshot == null) return; // nothing to restore (subject was absent)
    final exists = await subjectFile.exists();
    if (exists && await subjectFile.readAsString() == snapshot) return;
    await subjectFile.parent.create(recursive: true);
    await subjectFile.writeAsString(snapshot);
    print(
      '   subject restored to its certified-red shape — $reason, and a '
      'failed make leaves no subject mutation (issue #1036)',
    );
  }

  /// Bug #829: the spec Key Entity this UNIT behavior's FR traces to —
  /// the first declared entity (from the test list's Key entities
  /// section, which plan extracted from the spec) named in the
  /// behavior's description. Null for non-unit behaviors and when
  /// nothing traces (no declared entities / no name match): those keep
  /// their existing routing unchanged.
  Future<String?> _tracedEntityFor({
    required ArtifactRecord record,
    required String featureDir,
  }) async {
    if (!GenerationPlanner.isUnitBehaviorId(record.behaviorId)) return null;
    final List<DeclaredEntity> declared;
    try {
      declared = await TestListReader(featureDir).readEntities();
    } on TestListReadException {
      return null;
    }
    if (declared.isEmpty) return null;
    final desc = _descriptionFor(record);
    for (final entity in declared) {
      final m = RegExp('\\b${RegExp.escape(entity.name)}\\b').firstMatch(desc);
      if (m != null) return entity.name;
    }
    return null;
  }

  /// Bug #829: realize `entity create` steps idempotently. The core
  /// command regenerates the entity file unconditionally, so re-running
  /// it over an existing entity would silently destroy hand-tuned
  /// fields. Any `entity create -n <Name>` step whose entity file
  /// already exists is dropped from the effective plan (printed, never
  /// silent); the rest of the pipeline generates against the existing
  /// entity. Applies to every branch that emits the step (the bug-829
  /// unit entity pipeline and the issue-#758 acceptance branch alike).
  Future<GenerationPlan> _gateExistingEntityCreateSteps(
    GenerationPlan plan, {
    required String workingDirectory,
  }) async {
    final kept = <GenerationStepSpec>[];
    var gated = false;
    for (final step in plan.steps) {
      final name = _entityCreateStepName(step.args);
      if (name != null &&
          await locateEntityFile(workingDirectory, name) != null) {
        print(
          '   entity $name already exists — reuse (never overwrite '
          'hand-tuned fields)',
        );
        gated = true;
        continue;
      }
      kept.add(step);
    }
    if (!gated) return plan;
    return GenerationPlan(
      behaviorId: plan.behaviorId,
      feature: plan.feature,
      sourceCriterion: plan.sourceCriterion,
      steps: kept,
      unexpressibleReason: plan.unexpressibleReason,
    );
  }

  /// The `-n <Name>` of an `entity create` step's args, or null when the
  /// step creates no entity (or carries an unexpected argv shape — left
  /// untouched, fail-open to the un-gated step).
  String? _entityCreateStepName(List<String> args) {
    if (args.length < 4) return null;
    if (args[0] != 'entity' || args[1] != 'create') return null;
    final idx = args.indexOf('-n');
    if (idx < 0 || idx + 1 >= args.length) return null;
    return args[idx + 1];
  }

  // -----------------------------------------------------------------
  // Suite-guard regression scoping (issue #731).
  // -----------------------------------------------------------------

  /// The NEW failures (guard − baseline, by name) that THIS make can
  /// be held responsible for (issue #731). A new failing identifier is
  /// a regression only when
  ///
  ///   - it lives in the current behavior's own test file — the file
  ///     this make owns, so any new red in it is this make's doing; or
  ///   - its file had NO failures at baseline — the whole file was
  ///     passing before this make, so a red there is a genuine
  ///     collateral regression.
  ///
  /// Failures confined to a file that was ALREADY red at baseline
  /// belong to a pre-existing red behavior (e.g. an acceptance test
  /// deferred to phase 2). Such a behavior stays red across the whole
  /// cycle by design, and its failing-test identifier may even vary
  /// between the two suite runs (dynamic test names), so it never
  /// blocks this make: if only the current behavior's test passes,
  /// the make certifies green/skipped regardless of other behaviors
  /// being red.
  List<String> _regressionsAttributableToThisMake({
    required SuiteSnapshot baseline,
    required List<String> newFailures,
    required String testPath,
  }) {
    final baselineRedFiles = baseline.failedTests.map(_testFileOf).toSet();
    final regressed = <String>[];
    for (final id in newFailures) {
      final file = _testFileOf(id);
      final inCurrentBehaviorFile = _sameTestFile(testPath, file);
      final fileWasAlreadyRed = baselineRedFiles.any(
        (redFile) => _sameTestFile(file, redFile),
      );
      if (inCurrentBehaviorFile || !fileWasAlreadyRed) {
        regressed.add(id);
      }
    }
    return regressed;
  }

  /// The test-file path embedded in a failing-test identifier (or in a
  /// target test path). Handles the three shapes the suite transcript
  /// produces:
  ///
  ///   - progress lines: `test/foo_test.dart: group name test name`
  ///     (everything before the first `:` is the file);
  ///   - load failures: `loading test/foo_test.dart`;
  ///   - target test paths, which are already bare file paths.
  String _testFileOf(String id) {
    var s = id.trim();
    const loading = 'loading ';
    if (s.startsWith(loading)) s = s.substring(loading.length);
    final idx = s.indexOf(':');
    if (idx > 0) s = s.substring(0, idx);
    return s.trim();
  }

  /// Whether two test-file paths denote the same file. Paths compared
  /// may mix absolute target paths with runner-printed relative ones,
  /// so the match is a boundary-aware suffix match (the `/` boundary
  /// keeps `xu2_test.dart` from matching `u2_test.dart`).
  bool _sameTestFile(String a, String b) {
    final x = a.replaceAll(r'\', '/');
    final y = b.replaceAll(r'\', '/');
    return x == y || x.endsWith('/$y') || y.endsWith('/$x');
  }

  Future<_ResolvedTarget> _resolveTarget(
    String cwd,
    String? behaviorId,
    String? featureFlag,
  ) async {
    final registries = await _scanRegistries(cwd, featureFlag);
    // Issue #1471: the label is the canonical NAME, never the raw
    // `.specify/bugs/<slug>` reference.
    final featureLabel = featureFlag != null && featureFlag.isNotEmpty
        ? TddFeaturePaths.resolveWithPin(
            projectRoot: cwd,
            featureRef: featureFlag,
          ).name
        : featureFlag;

    if (behaviorId != null) {
      final matches = <_ResolvedTarget>[];
      for (final entry in registries) {
        final record = await entry.registry.findRecord(behaviorId);
        if (record != null) {
          matches.add(
            _ResolvedTarget(record, entry.featureDir, entry.featureName),
          );
        }
      }
      if (matches.isEmpty) {
        final plannedFeature = await _isPlannedInTestList(
          cwd,
          behaviorId,
          featureFlag,
        );
        if (plannedFeature != null) {
          throw MakeResolutionError(
            'behavior "$behaviorId" is planned in the $plannedFeature test '
            'list but has no gen artifacts. Run `zfa tdd gen $behaviorId` '
            'first.',
            outcome: MakeOutcome.runnerError,
            feature: plannedFeature,
          );
        }
        throw MakeResolutionError(
          'unknown behavior id "$behaviorId". No matching record in any '
          'specs/<feature>/tdd/artifacts.json'
          '${featureLabel != null ? ' for feature $featureLabel' : ''}. '
          'Run `zfa tdd gen $behaviorId` to materialize it.',
          outcome: MakeOutcome.runnerError,
          feature: featureLabel,
        );
      }
      if (matches.length > 1) {
        final list = matches
            .map((m) => '${m.record.behaviorId} (${m.featureName})')
            .join(', ');
        throw MakeResolutionError(
          'ambiguous behavior id "$behaviorId" registered in multiple '
          'features: $list. Use --feature to disambiguate.',
          outcome: MakeOutcome.runnerError,
        );
      }
      final target = matches.single;
      await _requireTestArtifact(cwd, target);
      return target;
    }

    // No id: infer ONLY when exactly one behavior has gen artifacts
    // and certified-red evidence — the precondition for `make`.
    final candidates = <_ResolvedTarget>[];
    for (final entry in registries) {
      final certified = await _certifiedRedBehaviors(entry.featureDir);
      for (final record in await entry.registry.loadAll()) {
        if (certified.contains(record.behaviorId)) {
          final target = _ResolvedTarget(
            record,
            entry.featureDir,
            entry.featureName,
          );
          await _requireTestArtifact(cwd, target);
          candidates.add(target);
        }
      }
    }
    if (candidates.isEmpty) {
      throw MakeResolutionError(
        'no behavior with both gen artifacts and certified-red evidence — '
        'nothing to make. Run `zfa tdd verify-red <behavior-id>` first.',
        outcome: MakeOutcome.notCertifiedRed,
      );
    }
    if (candidates.length > 1) {
      final list = candidates
          .map((c) => '${c.record.behaviorId} (${c.featureName})')
          .join(', ');
      throw MakeResolutionError(
        'ambiguous invocation: multiple behaviors have certified-red '
        'evidence: $list. Pass an explicit behavior id.',
        outcome: MakeOutcome.runnerError,
      );
    }
    return candidates.single;
  }

  Future<void> _requireTestArtifact(String cwd, _ResolvedTarget target) async {
    final recordedPath = target.record.testPath;
    final testPath = p.isAbsolute(recordedPath)
        ? recordedPath
        : p.join(cwd, recordedPath);
    if (!await File(testPath).exists()) {
      throw MakeResolutionError(
        'the registry record for behavior "${target.record.behaviorId}" '
        'points to a missing test file at "$recordedPath". Run '
        '`zfa tdd gen ${target.record.behaviorId}` to restore its artifacts.',
        outcome: MakeOutcome.runnerError,
        feature: target.featureName,
      );
    }
  }

  Future<List<_RegistryEntry>> _scanRegistries(
    String cwd,
    String? featureFlag,
  ) async {
    if (featureFlag != null && featureFlag.isNotEmpty) {
      // Issue #1471: the reference may name a bug directory
      // (`.specify/bugs/<slug>`) outside `specs/` — resolve it through the
      // shared resolver so the registry is read from the REAL directory and
      // the entry is labelled with the canonical name (a plain basename).
      final resolved = TddFeaturePaths.resolveWithPin(
        projectRoot: cwd,
        featureRef: featureFlag,
      );
      final featureDir = resolved.dir;
      return [
        _RegistryEntry(
          resolved.name,
          featureDir,
          ArtifactRegistry(featureDir: featureDir),
        ),
      ];
    }
    final specsDir = Directory(p.join(cwd, 'specs'));
    if (!await specsDir.exists()) return const [];
    final dirs = specsDir.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final entries = <_RegistryEntry>[];
    for (final dir in dirs) {
      final registryFile = File(p.join(dir.path, 'tdd', 'artifacts.json'));
      if (await registryFile.exists()) {
        final name = p.basename(dir.path);
        entries.add(
          _RegistryEntry(
            name,
            dir.path,
            ArtifactRegistry(featureDir: dir.path),
          ),
        );
      }
    }
    return entries;
  }

  /// Whether [behaviorId] has a red entry in the feature's cycle-log
  /// (the precondition for `make` per FR-001).
  Future<bool> _hasCertifiedRed(String featureDir, String behaviorId) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return false;
    final raw = await file.readAsString();
    // Issue #1353: scan EVERY section — a stale non-red section from an
    // earlier failed attempt (the normal shape of a resumed run) must not
    // shadow a later certified-red section for the same behavior.
    for (final section in splitCycleLogSections(raw)) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null || behavior.group(1) != behaviorId) continue;
      if (RegExp(r'^- kind: red$', multiLine: true).hasMatch(section)) {
        return true;
      }
    }
    return false;
  }

  /// Behavior ids that have a red entry in the feature's cycle-log.
  Future<Set<String>> _certifiedRedBehaviors(String featureDir) async {
    final file = File(p.join(featureDir, 'tdd', 'cycle-log.md'));
    if (!await file.exists()) return const {};
    final raw = await file.readAsString();
    final certified = <String>{};
    for (final section in splitCycleLogSections(raw)) {
      final behavior = RegExp(
        r'^- behavior: (\S+)',
        multiLine: true,
      ).firstMatch(section);
      if (behavior == null) continue;
      if (RegExp(r'^- kind: red$', multiLine: true).hasMatch(section)) {
        certified.add(behavior.group(1)!);
      }
    }
    return certified;
  }

  /// Whether [behaviorId] appears as a row in any feature's
  /// `tdd/test-list.md`. Returns the feature name when found.
  Future<String?> _isPlannedInTestList(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    List<Directory> dirs;
    if (featureFlag != null && featureFlag.isNotEmpty) {
      // Issue #1471: resolve the reference so a bug directory
      // (`.specify/bugs/<slug>`) is scanned at its real location.
      dirs = [
        Directory(
          TddFeaturePaths.resolveWithPin(
            projectRoot: cwd,
            featureRef: featureFlag,
          ).dir,
        ),
      ];
    } else {
      final specsDir = Directory(p.join(cwd, 'specs'));
      if (!await specsDir.exists()) return null;
      dirs = specsDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    }
    for (final dir in dirs) {
      final file = File(p.join(dir.path, 'tdd', 'test-list.md'));
      if (!await file.exists()) continue;
      final raw = await file.readAsString();
      for (final line in raw.split('\n')) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('|') || trimmed.contains('---')) continue;
        final cells = trimmed.split('|').map((s) => s.trim()).toList();
        if (cells.length > 1 && cells[1] == behaviorId) {
          return p.basename(dir.path);
        }
      }
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Bug #826 — empty inner make plan pre-flight.
  // -------------------------------------------------------------------

  /// Issue #1330 — the subject-edit fallback plan for a gated plan whose
  /// FIRST step is the bare `make <name>` that resolves to nothing, or
  /// null when the shape offers no subject-edit step to fall back to.
  ///
  /// After the bug-#829 entity gate drops an `entity create` step for an
  /// already-generated entity, a sibling acceptance behavior's plan starts
  /// with the bare `make <Entity>` — the one-shot scaffold with nothing to
  /// generate — followed by the subject-edit step that turned the earlier
  /// siblings green. Aborting the whole make as `no-op` (the bug #826
  /// verdict) wastes that subject-edit path and dead-ends the run: phase 2
  /// re-plans the identical steps and no-ops identically (issue #1330).
  /// When the remaining steps still carry a subject-edit step (`tdd wire`
  /// / `tdd func`), the caller drops the no-op make step and runs the
  /// reduced plan — the entity is reused AS-IS (never regenerated,
  /// hand-tuned fields preserved) and the subject edit proceeds. Plans
  /// without a subject-edit step keep the bug #826 verdict (fail-closed
  /// backward compatibility — nothing to fall back TO).
  GenerationPlan? _subjectEditFallbackPlan(GenerationPlan plan) {
    if (plan.steps.length < 2) return null;
    final first = plan.steps.first.args;
    if (first.length < 2 || first.first != 'make') return null;
    final rest = plan.steps.sublist(1);
    if (!rest.any(_isSubjectEditStep)) return null;
    return GenerationPlan(
      behaviorId: plan.behaviorId,
      feature: plan.feature,
      sourceCriterion: plan.sourceCriterion,
      steps: rest,
      unexpressibleReason: plan.unexpressibleReason,
    );
  }

  /// Whether a pipeline step edits the behavior's subject stub in place —
  /// the `tdd wire` / `tdd func` subject-edit surfaces (the path that
  /// turned the earlier sibling behaviors green in the issue #1330 repro).
  bool _isSubjectEditStep(GenerationStepSpec step) {
    final args = step.args;
    return args.length >= 2 &&
        args[0] == 'tdd' &&
        (args[1] == 'wire' || args[1] == 'func');
  }

  /// The entity/slug name when [plan]'s FIRST step is a bare
  /// `zfa make <name>` invocation — no explicit plugin ids after the name
  /// — i.e. the default-resolution shape whose active-plugin set the
  /// empty-plan pre-flight can mirror in-process. Null for every other
  /// plan shape (entity create, tdd func, tdd wire, composition, or a
  /// make step with explicit plugin ids), so the pre-flight never
  /// short-circuits a plan it cannot model.
  String? _bareMakeName(GenerationPlan plan) {
    if (plan.steps.isEmpty) return null;
    final first = plan.steps.first.args;
    if (first.length < 2 || first.first != 'make') return null;
    // Anything positional after the name is an explicit plugin id — the
    // child plan would not be the default-resolution shape.
    final explicitIds = first
        .skip(2)
        .where((a) => !a.startsWith('-'))
        .toList(growable: false);
    if (explicitIds.isNotEmpty) return null;
    return first[1];
  }

  /// Whether a real `zfa make <name>` child in [projectRoot] would resolve
  /// to zero active plugins — the "❌ No active plugins to run." branch of
  /// the make command. Mirrors the child's own resolution: same process
  /// registry, same project config, no explicit plugin ids, no preset.
  /// Any resolution error fails OPEN (the subprocess path runs as before).
  bool _innerMakePlanIsEmpty(String projectRoot, String name) {
    try {
      final manager = PluginManager(
        registry: PluginRegistry.instance,
        config: ZfaConfig.load(projectRoot: projectRoot),
        pluginConfig: PluginConfig.load(projectRoot: projectRoot),
        projectRoot: projectRoot,
      );
      return manager.resolvePlan(name: name).activePlugins.isEmpty;
    } catch (_) {
      return false;
    }
  }

  void _printSummary({
    required String behavior,
    required MakeOutcome outcome,
    required String feature,
  }) {
    print('make: behavior=$behavior outcome=${outcome.label} feature=$feature');
    // Issue #969: the outcome label IS the exit class (shipped
    // taxonomy, carried verbatim into the envelope).
    _verdict
      ..exitClass = outcome.label
      ..outcome = switch (outcome) {
        MakeOutcome.green => VerdictOutcome.pass,
        MakeOutcome.greenWithFailedBuild => VerdictOutcome.pass,
        // Issue #1331: the adopted re-drive re-certified green — a pass,
        // distinguishable by its own exit class.
        MakeOutcome.adopted => VerdictOutcome.pass,
        // Issue #1345: compose-placeholder re-entry exits 0 with green
        // evidence — the terminal success grades as pass.
        MakeOutcome.adoptedPlaceholder => VerdictOutcome.pass,
        MakeOutcome.skipped => VerdictOutcome.stopped,
        _ => VerdictOutcome.fail,
      }
      ..details['behavior'] = behavior
      ..feature = feature == 'unknown' ? null : feature;
  }
}

/// `--feature` lands in a filesystem path: accept exactly the shapes
/// [TddFeaturePaths] resolves (a plain segment, `specs/<name>`,
/// `.specify/bugs/<slug>`, or an absolute path) and refuse the rest —
/// `.`, `..`, a traversal shape, or a trailing separator (issue #1471).
void _validateFeatureSegment(String feature) {
  if (TddFeaturePaths.isSupportedRef(feature) &&
      !feature.endsWith('/') &&
      !feature.endsWith(r'\')) {
    return;
  }
  throw UsageException(
    'invalid --feature "$feature": expected a single spec directory name '
        'such as 047-tdd-make, not a path.',
    'zfa tdd make [<behavior-id>] [--feature <name>]',
  );
}

class _RegistryEntry {
  const _RegistryEntry(this.featureName, this.featureDir, this.registry);

  final String featureName;
  final String featureDir;
  final ArtifactRegistry registry;
}

class _ResolvedTarget {
  const _ResolvedTarget(this.record, this.featureDir, this.featureName);

  final ArtifactRecord record;
  final String featureDir;
  final String featureName;
}
