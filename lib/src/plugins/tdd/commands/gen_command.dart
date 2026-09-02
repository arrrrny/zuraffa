/// `zfa tdd gen <behavior-id>` — materializes a planned behavior into
/// exactly ONE test + ONE compilable subject (spec 044-test-tdd-generation,
/// FR-001..011).
///
/// The command:
///   1. Loads `specs/<feature>/tdd/test-list.md` through the SHARED
///      [TestListReader] (bug #617: gen previously carried a private
///      6-column parser that silently skipped the 4-column rows plan
///      writes, so every planned behavior was "unknown" to gen and the
///      full loop stopped at its first step). Looks up the behavior row
///      by id; the target defaults in the reader. If the id is unknown
///      or the row is malformed, exits non-zero BEFORE any file is
///      written (FR-002).
///   2. Computes the test path + subject path + runnable test name for the
///      behavior. Path convention (bug #827): the artifacts are namespaced
///      by feature-slug — `test/tdd/<feature-slug>/<snake-id>_test.dart` and
///      `lib/tdd/<feature-slug>/<snake-id>_subject.dart` — so two features
///      that plan the same behavior id never map to the same file (the flat
///      pre-#827 layout made feature N+1 unstartable while feature N's
///      artifacts existed; registries are per-feature, so the second
///      feature's gen was refused by the FR-008 guardrail for a file it did
///      not own). Legacy flat projects migrate via `zfa tdd migrate-paths`.
///   3. Delegates test file writing to [BehaviorTestWriter] and subject
///      file writing to [SubjectWriter].
///   4. Persists an [ArtifactRecord] via [ArtifactRegistry] (FR-007).
///   5. Prints a structured result with the six required fields (FR-005):
///      behavior_id, source_criterion, test_path, subject_path,
///      runnable_test_name, ownership.
///
/// Idempotent: a repeat `gen` for the same behavior is a no-op that returns
/// `Ownership.reused` for both artifacts (FR-006) — with one exception
/// (bug #683): when the stub on disk was written by an OLDER binary (its
/// content no longer matches what the current binary would render) and is
/// still an `UnimplementedError` stub, the pair is regenerated with a
/// `binary updated, stub regenerated` note so a rebuilt binary cannot
/// silently leave a stale stub behind. A progressed subject (no
/// `UnimplementedError` left) is never clobbered.
///
/// Ownership conflict: if a file exists on disk but the registry has no
/// record for it, exits non-zero WITHOUT modifying the file (FR-008).
///
/// `--dry-run`: plans the pair without writing anything (FR-009).
///
/// Bounded flow (bug #744): every awaited stage of the flow — behavior
/// resolution, ownership preflight, the two writer writes, the registry
/// append, and the staleness re-render — runs under ONE wall-clock
/// deadline (`--timeout`, minutes with fractions allowed, default
/// 0.5 = 30s: the same acceptance budget the #744 records name, and the
/// same unit/format as every other TDD command's `--timeout` per #742).
/// The deadline is enforced INSIDE the flow — hardening over the merged
/// #748 wrapper-level budget: a fired deadline surfaces from the flow
/// body itself, so the transactional cleanup removes whatever THIS
/// attempt created before the misfire-stop classification prints (a
/// timed-out gen can no longer leave an orphan pair file with no
/// registry record, which preflight reports as an FR-008 ownership
/// conflict and which would poison the next run). Because Dart futures
/// cannot be cancelled, every stage re-checks the expired deadline
/// BEFORE it starts, so an abandoned continuation aborts at its next
/// stage boundary instead of silently completing writes or the registry
/// append after the command has already reported the timeout. The
/// misfire-stop follows the #742 house pattern: one classification line
/// naming behavior, step, and `outcome=timeout`, exit 1 — no exception
/// noise. The flow spawns NO subprocess of its own (test execution is
/// verify-red/make's contract, not gen's), so the deadline needs no
/// process-kill side effects. The flow also depends only on the
/// test-list row, the registry, and the pair on disk — never on
/// run-state or suite health — so a DEFERRED/unexpressible predecessor
/// (A1 red at its phase-2 make, bug #625/#657) cannot block a later gen
/// (A2): the #738-era deadlock inspection found no cross-behavior wait
/// in this flow, and the deadline caps whatever could stall.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../models/channel_scenario.dart';
import '../services/artifact_registry.dart';
import '../services/cross_feature_ownership.dart';
import '../services/behavior_test_writer.dart';
import '../services/generated_shape.dart';
<<<<<<< HEAD
import '../services/golden_harness_writer.dart';
=======
import '../services/platform_harness_context.dart';
import '../services/platform_harness_subject_writer.dart';
import '../services/platform_harness_test_writer.dart';
>>>>>>> 802ef8b8 (fix(831): platform-channel test harness — zfa tdd fake generates certified fakes driven by committed scenario intent)
import '../services/subject_writer.dart';
import '../services/test_list_reader.dart';
import '../services/theme_harness_subject_writer.dart';
import '../services/theme_harness_test_writer.dart';
import '../tdd_plugin.dart';
import '../services/tdd_timeout.dart';
import '../../../core/project/project_root.dart';

class GenCommand extends Command<void> {
  GenCommand(this.plugin) {
    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      help: 'Plan the test+subject pair without writing anything (FR-009).',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'kind',
      allowed: ['acceptance', 'unit', 'widget'],
      help:
          'Override the subject kind taken from the test-list row (bug '
          '#830). `widget` emits a testWidgets pair: a view-builder subject '
          'stub plus a widget test that pumps the view inside an app shell '
          'and asserts the acceptance scenario. Unknown values are a usage '
          'error.',
    );
    argParser.addFlag(
      'golden',
      help:
          'Widget kind only (bug #830): append a matchesGoldenFile baseline '
          'hook to the generated widget test. Baselines are committed per '
          'platform under test/tdd/goldens/ and refreshed with `flutter test '
          '--update-goldens`.',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addFlag(
      'adopt',
      help:
          'Recovery mode (bug #840): when files exist on disk unowned by the '
          'registry (post-crash, post-merge), verify their content matches '
          'the generated artifact shape (provenance header + behavior id), '
          'then register ownership and audit-log the adoption instead of '
          'refusing. Files that do not match the shape are never adopted; '
          'missing halves are generated.',
      defaultsTo: false,
      negatable: false,
    );
    argParser.addOption(
      'feature',
      help:
          'Feature name (e.g. 044-test-tdd-generation). When set, only '
          'specs/<feature>/tdd/test-list.md is scanned for the behavior id. '
          'When omitted, all feature dirs are scanned and the first match '
          'wins (with a preference for the cwd-matching feature).',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addOption(
      'timeout',
      help:
          'Wall-clock budget for the whole gen flow, in MINUTES — fractions '
          'allowed (0.5 = 30 seconds, the default), the same unit and '
          'format as every other TDD command\'s --timeout (bug #742). On '
          'expiry the flow stops with outcome=timeout and a non-zero exit '
          'instead of hanging indefinitely (bug #744).',
      defaultsTo: '$defaultTimeoutMinutes',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'gen';

  @override
  String get description =>
      'Generate a failing test + compiling source stub for a behavior '
      '(spec 044-test-tdd-generation, FR-001..011).';

  @override
  String get invocation =>
      'zfa tdd gen <behavior-id> [--dry-run] [--kind widget] [--golden]';

  /// The default wall-clock budget for the whole gen flow: 0.5 minutes =
  /// 30 seconds (bug #744 — the same acceptance budget the bug records
  /// name: "A2 completes within 30s"). Minutes, so `--timeout` shares
  /// the #742 unit across the TDD subsystem.
  static const double defaultTimeoutMinutes = 0.5;

  /// The default budget as a [Duration].
  static final Duration defaultBudget = Duration(
    microseconds: (defaultTimeoutMinutes * Duration.microsecondsPerMinute)
        .round(),
  );

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Behavior id is required: zfa tdd gen <behavior-id>');
    }
    final behaviorId = rest.first;
    final dryRun = argResults!['dry-run'] as bool;
    final adopt = argResults!['adopt'] as bool;
    // Bug #830: explicit subject-kind override and the widget-only golden
    // baseline hook. The override is validated by args' `allowed` list;
    // the golden flag is validated against the EFFECTIVE kind below
    // (widget-only — a golden hook in a plain-function test is nonsense).
    final kindOverrideName = argResults!['kind'] as String?;
    final golden = argResults!['golden'] as bool;
    final BehaviorKind? kindOverride;
    if (kindOverrideName == null) {
      kindOverride = null;
    } else {
      kindOverride = BehaviorKind.values.firstWhere(
        (k) => k.name == kindOverrideName,
      );
    }
    final featureFlag = argResults!['feature'] as String?;
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults!['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    // Bug #742 unit contract: one shared parser for every TDD --timeout
    // (minutes, fractions allowed). A bad value is a usage error, exactly
    // like the other flags.
    final Duration budget;
    try {
      budget =
          parseTddTimeoutMinutes(argResults!['timeout'] as String?) ??
          defaultBudget;
    } on TddTimeoutFormatException catch (e) {
      usageException('zfa tdd gen: ${e.message}');
    }

    // Bug #744: the WHOLE flow runs under one wall-clock deadline. Unlike
    // a wrapper-level Future.timeout, the deadline is enforced INSIDE the
    // flow: a fired deadline surfaces from the flow body itself — after
    // the transactional cleanup removed whatever this attempt created —
    // and an abandoned continuation (Dart futures cannot be cancelled)
    // aborts at its next stage boundary instead of silently completing
    // writes or the registry append after the timeout was reported.
    final deadline = _FlowDeadline(budget);
    try {
      await _generate(
        behaviorId,
        dryRun: dryRun,
        adopt: adopt,
        kindOverride: kindOverride,
        golden: golden,
        featureFlag: featureFlag,
        cwd: cwd,
        deadline: deadline,
      );
    } on _GenFlowTimeout catch (e) {
      // Misfire-stop, #742 house pattern (make_command): the
      // classification is printed ONCE through the capturable stdout
      // channel and the command exits 1 — no stderr duplication and no
      // "Bad state:" exception noise from the runner's generic handler.
      print(
        'zfa tdd gen: timeout after ${formatTddTimeout(budget)} — '
        'behavior=$behaviorId step=${e.stage} outcome=timeout',
      );
      print(
        '   a gen stage exceeded its wall-clock deadline and was stopped '
        'before it could hang (bug #742/#744 safety net). Re-run with '
        '--timeout <minutes> to raise the budget.',
      );
      exitCode = 1;
      return;
    }
  }

  /// The deadline-bounded flow body, verbatim the pre-#744 contract:
  /// resolve → preflight → write → register → (staleness check) → print.
  /// Every awaited stage is bounded by [run]'s shared deadline.
  Future<void> _generate(
    String behaviorId, {
    required bool dryRun,
    required bool adopt,
    required BehaviorKind? kindOverride,
    required bool golden,
    required String? featureFlag,
    required String cwd,
    required _FlowDeadline deadline,
  }) async {
    // Every awaited stage runs under the shared deadline (bug #744). A
    // fired deadline throws _GenFlowTimeout from INSIDE the flow so the
    // transactional cleanup below runs before the classification
    // surfaces; an already-expired deadline aborts a stage BEFORE it
    // starts, which is what stops an abandoned continuation (the
    // underlying stage's I/O cannot be cancelled) from completing later
    // stages — notably the registry append — after the timeout was
    // reported.
    Future<T> bounded<T>(Future<T> stage, String stageName) async {
      if (deadline.expired) throw _GenFlowTimeout(stageName);
      try {
        return await stage.timeout(deadline.remaining());
      } on TimeoutException {
        throw _GenFlowTimeout(stageName);
      }
    }

    // Resolve the behavior. If --feature is set, only scan that one
    // feature's test-list. Otherwise, scan all features and prefer
    // `044-test-tdd-generation` (the feature this command lives under).
    // A malformed test list stops honestly naming the line (FR-011) —
    // never silently skipped (the anti-pattern behind bug #617).
    final (Behavior?, String, String) resolved;
    try {
      resolved = await bounded(
        _resolveBehavior(cwd, behaviorId, featureFlag),
        'resolve test list',
      );
    } on TestListReadException catch (e) {
      stderr.writeln('zfa tdd gen: ${e.message}');
      throw StateError('zfa tdd gen: malformed test list — ${e.message}');
    }
    final (behavior, featureDir, featureName) = resolved;
    if (behavior == null) {
      // Issue #890 diagnosability: a wrong project root (no specs/ at all)
      // used to surface as a bare `unknown behavior id`, which reads like a
      // missing row and hides the real problem. Name the scanned root so a
      // mis-resolution is visible on the spot.
      if (!await Directory('$cwd/specs').exists()) {
        stderr.writeln(
          'zfa tdd gen: no specs/ directory under the resolved project '
          'root: $cwd',
        );
        stderr.writeln(
          '   the project root may have been mis-resolved — pass '
          '--project <root> to pin it explicitly.',
        );
      }
      stderr.writeln(
        'zfa tdd gen: unknown behavior id "$behaviorId". '
        'No matching row found in any specs/<feature>/tdd/test-list.md'
        '${featureFlag != null ? " for feature $featureFlag" : ""}.',
      );
      throw StateError('zfa tdd gen: unknown behavior id "$behaviorId"');
    }

    // Bug #830: effective subject kind — the --kind override wins over
    // the test-list row's kind. --golden is widget-only: a golden hook
    // in a plain-function/scenario-runner test is meaningless, so it is
    // a usage error (fail fast before ANY file is written, FR-002).
    final effectiveKind = kindOverride ?? behavior.kind;
    if (golden && effectiveKind != BehaviorKind.widget) {
      usageException(
        'zfa tdd gen: --golden requires a widget-kind behavior '
        '(use --kind widget or mark the test-list row widget).',
      );
    }
    final effectiveBehavior =
        identical(kindOverride, null) || kindOverride == behavior.kind
        ? behavior
        : Behavior(
            id: behavior.id,
            feature: behavior.feature,
            kind: effectiveKind,
            description: behavior.description,
            sourceCriterion: behavior.sourceCriterion,
            target: behavior.target,
            state: behavior.state,
          );

    // Validate required fields up front (FR-002).
    final missingFields = _missingRequiredFields(behavior);
    if (missingFields.isNotEmpty) {
      stderr.writeln(
        'zfa tdd gen: behavior "$behaviorId" is missing required '
        'field(s): ${missingFields.join(', ')}. Refusing to write any '
        'file.',
      );
      throw StateError(
        'zfa tdd gen: missing required field(s): ${missingFields.join(', ')}',
      );
    }

    // Compute paths. Bug #827: the artifacts are namespaced by feature-slug
    // so two features planning the same behavior id never collide on one
    // flat file (the registry is per-feature; the flat layout made feature
    // N+1's gen an FR-008 refusal against feature N's artifacts).
    final snakeId = _toSnakeCase(behavior.id);
    _validateFeatureSegment(featureName);
    final testPath = '$cwd/test/tdd/$featureName/${snakeId}_test.dart';
    final subjectPath = '$cwd/lib/tdd/$featureName/${snakeId}_subject.dart';
    // Bug #871: the composite third segment is the PURE description —
    // the id is embedded exactly once (segment 2). The old
    // `'$testPath::$id::$id — $description'` double-embed leaked an
    // `<id> — ` prefix into every consumer that extracts the description
    // segment, and the tdd planner's capitalized-trace fallback then
    // captured the id as the entity name (`make A1` instead of
    // `make Todo`). The generated test's name (BehaviorTestWriter) is
    // the same pure description, so `--plain-name` matching agrees.
    final runnableTestName =
        '$testPath::${behavior.id}::${behavior.description}';

    // Issue #831: platform behaviors drive a platform channel through
    // the certified fake + committed scenario written by
    // `zfa tdd fake <channel> --behavior <id>`. Both must exist BEFORE
    // any gen artifact is written — a refusal happens at this boundary,
    // with the exact remedy, never a half-written pair.
    PlatformHarnessContext? platformContext;
    if (effectiveBehavior.kind == BehaviorKind.platform) {
      platformContext = _resolvePlatformContext(
        cwd: cwd,
        featureDir: featureDir,
        featureName: featureName,
        snakeId: snakeId,
        behaviorId: behavior.id,
      );
    }

    final registry = ArtifactRegistry(featureDir: featureDir);

    // Build the proposed record, then preflight ownership without changing
    // the registry. The record is appended only after both writes succeed.
    var record = ArtifactRecord(
      behaviorId: behavior.id,
      feature: featureName,
      sourceCriterion: behavior.sourceCriterion,
      testPath: testPath,
      subjectPath: subjectPath,
      runnableTestName: runnableTestName,
      testOwnership: dryRun ? Ownership.planned : Ownership.created,
      subjectOwnership: dryRun ? Ownership.planned : Ownership.created,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    // Bug #840: adopt mode tracks which unowned files were verified and
    // kept, and which halves this invocation created — the transactional
    // cleanup must NEVER delete an adopted file (gen did not create it).
    final adoptedPaths = <String>[];
    final createdPaths = <String>[];

    // Bug #835: the golden-fixture lane paths for an ffi behavior (null
    // for every other kind), surfaced in the structured output + verdict.
    GoldenHarnessPaths? goldenPaths;

    var adoptConflict = false;
    try {
      record = await bounded(
        registry.preflight(record, dryRun: dryRun),
        'ownership preflight',
      );
    } on OwnershipConflict catch (e) {
      if (!adopt || dryRun) {
        // Bug #874: consult ALL feature registries before calling the
        // conflicting file unowned. Another feature's artifact is
        // foreign-owned — the verdict names the owner and the migrate
        // fix; adopting it into a second registry would corrupt
        // ownership.
        final foreignOwner = await bounded(
          foreignOwnerOf(cwd, [e.path], excludeFeature: featureName),
          'ownership preflight: cross-registry lookup',
        );
        if (foreignOwner != null) {
          final migrateFix = 'zfa tdd migrate-paths $foreignOwner';
          _printVerdict(
            behaviorId: behavior.id,
            verdict: 'foreign-owned',
            reason:
                'the conflicting file is owned by feature "$foreignOwner" '
                '— never adopt another feature\'s artifacts; run '
                '`$migrateFix` to move the owning feature\'s artifacts '
                'to the namespaced layout',
          );
          exitCode = 1;
          stderr.writeln(
            'zfa tdd gen: foreign-owned — the conflicting file is owned '
            'by feature $foreignOwner',
          );
          throw StateError(
            'zfa tdd gen: foreign-owned — the conflicting file is owned '
            'by feature $foreignOwner',
          );
        }
        _printVerdict(
          behaviorId: behavior.id,
          verdict: 'refused',
          reason: 'ownership conflict: ${e.toString()}',
        );
        exitCode = 1;
        stderr.writeln('zfa tdd gen: ownership conflict — $e');
        throw StateError('zfa tdd gen: ownership conflict — $e');
      }
      adoptConflict = true;
    }

    if (adoptConflict) {
      // Bug #840 adoption: verify every existing unowned file against the
      // generated shape before registering anything. A prior registry
      // record means the conflict is a registry/paths disagreement, not
      // unowned files — there is nothing to adopt.
      final prior = await bounded(
        registry.findRecord(behavior.id),
        'adopt: registry lookup',
      );
      if (prior != null) {
        _printVerdict(
          behaviorId: behavior.id,
          verdict: 'refused',
          reason:
              'a registry record for "${behavior.id}" already exists — '
              'nothing unowned to adopt',
        );
        exitCode = 1;
        throw StateError(
          'zfa tdd gen: --adopt refused — a registry record for '
          '"${behavior.id}" already exists',
        );
      }
      // Bug #874: the existing file(s) may be another feature's recorded
      // artifact. Consult ALL feature registries before calling anything
      // unowned — a foreign-owned file is refused with the migrate hint,
      // never registered into a second registry. (House pattern: the
      // refusal returns so the JSON verdict stays the final stdout line.)
      final existingConflicts = [
        if (File(testPath).existsSync()) testPath,
        if (File(subjectPath).existsSync()) subjectPath,
      ];
      final adoptForeignOwner = await bounded(
        foreignOwnerOf(cwd, existingConflicts, excludeFeature: featureName),
        'adopt: cross-registry lookup',
      );
      if (adoptForeignOwner != null) {
        final migrateFix = 'zfa tdd migrate-paths $adoptForeignOwner';
        _printVerdict(
          behaviorId: behavior.id,
          verdict: 'foreign-owned',
          reason:
              'the conflicting file is owned by feature '
              '"$adoptForeignOwner" — never adopt another feature\'s '
              'artifacts; run `$migrateFix` to move the owning '
              'feature\'s artifacts to the namespaced layout',
        );
        exitCode = 1;
        return;
      }
      for (final (role, path, shaped) in [
        ('test', testPath, matchesGeneratedTestShape),
        ('subject', subjectPath, matchesGeneratedSubjectShape),
      ]) {
        final file = File(path);
        if (!await bounded(file.exists(), 'adopt: stat $role')) continue;
        final content = await bounded(file.readAsString(), 'adopt: read $role');
        if (!shaped(content, behavior.id)) {
          _printVerdict(
            behaviorId: behavior.id,
            verdict: 'refused',
            reason:
                '$role file "$path" exists unowned but does not match the '
                'generated $role shape (provenance header + behavior_id)',
          );
          // House pattern (spec 048): signal through exitCode and return,
          // so the JSON verdict stays the final stdout line (bug #840).
          exitCode = 1;
          return;
        }
        adoptedPaths.add(path);
      }
      print(
        'note: adopting ${adoptedPaths.length} unowned file(s) for '
        '"${behavior.id}" (bug #840)',
      );
    }

    // Write a new pair transactionally from the command's perspective. Any
    // writer or registry failure removes artifacts created by this attempt
    // (never the adopted files — bug #840).
    //
    // Writer dispatch (issue #841): theme-kind behaviors get the
    // theme-harness pair (four-proof widget test + subject contract);
    // every other kind gets the plain-function pair (spec 044).
    if (record.testOwnership != Ownership.reused && !dryRun) {
      final adoptTest = adoptedPaths.contains(testPath);
      final adoptSubject = adoptedPaths.contains(subjectPath);
      final writers = _writersFor(behavior, platformContext: platformContext);
      try {
        if (!adoptTest) {
          await bounded(
            writers.writeTest(
              behavior: effectiveBehavior,
              testPath: testPath,
              subjectPath: subjectPath,
              golden: golden,
            ),
            'write test file',
          );
          createdPaths.add(testPath);
        }
        if (!adoptSubject) {
          await bounded(
            writers.writeSubject(
              behavior: effectiveBehavior,
              subjectPath: subjectPath,
            ),
            'write subject file',
          );
          createdPaths.add(subjectPath);
        }
        // Bug #835: an ffi behavior also gets the GOLDEN FIXTURE lane —
        // the marked integration-tier test + the golden fixtures. Same
        // transactional attempt: a failure later in this block removes
        // what THIS invocation created. Only newly created pairs get the
        // lane (a reused pair keeps its recorded golden data — the
        // writer itself never overwrites an existing file either).
        if (behavior.kind == BehaviorKind.ffi) {
          final golden = await bounded(
            const GoldenHarnessWriter().write(
              behavior: behavior,
              projectRoot: cwd,
              featureName: featureName,
              snakeId: snakeId,
            ),
            'write golden fixture lane',
          );
          createdPaths.addAll(golden.createdFiles);
          goldenPaths = golden;
        }
        record = await bounded(registry.append(record), 'registry append');
      } catch (error, stackTrace) {
        // Transactional cleanup: remove what THIS attempt created. The
        // timeout path is included by construction — the deadline fires
        // inside the flow, so _GenFlowTimeout is caught here like any
        // other failure (the pre-hardening #748 wrapper-level .timeout()
        // bypassed this catch entirely and could leave an orphan file
        // that poisons the next run with an FR-008 ownership conflict).
        for (final path in createdPaths) {
          await _deleteIfCreated(path);
        }
        if (error is _GenFlowTimeout) {
          // The timed-out stage's underlying I/O cannot be cancelled and
          // may complete shortly after the deadline fired, re-creating an
          // orphan file AFTER the cleanup above. One grace pass
          // re-deletes; the abandoned continuation cannot reach the
          // registry append because every subsequent stage re-checks the
          // expired deadline and aborts before starting. Residual
          // window: an I/O completing after this pass — accepted, and
          // strictly narrower than pre-hardening, which had no cleanup
          // at all.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          for (final path in createdPaths) {
            await _deleteIfCreated(path);
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (adoptedPaths.isNotEmpty) {
        await bounded(
          _auditAdopt(featureDir, featureName, behavior.id, adoptedPaths),
          'adopt: audit log',
        );
      }
    }

    // Binary-change detection (bug #683): a `reused/reused` preflight only
    // proves the stub on disk was owned by SOME zfa binary — not by the
    // CURRENT one. After a rebuild that changes what the writers render,
    // the stale stub silently regressed the resumed pipeline (make ran the
    // test against the old stub). Option B (lenient): when the subject on
    // disk is still an UnimplementedError stub, compare its content against
    // what the current binary would render; regenerate the pair when they
    // differ, stay silent when they match. A subject that no longer
    // contains UnimplementedError has PROGRESSED (func scaffolding or a
    // real implementation) and must never be clobbered.
    var regeneratedNote = false;
    if (record.testOwnership == Ownership.reused &&
        record.subjectOwnership == Ownership.reused &&
        !dryRun) {
      regeneratedNote = await _regenerateStaleStub(
        behavior: effectiveBehavior,
        featureName: featureName,
        testPath: testPath,
        subjectPath: subjectPath,
        platformContext: platformContext,
        bounded: bounded,
      );
    }

    // Print the structured result. Use `print` (not `stdout.writeln`) so
    // the CliRunner's runCapturing zone can capture it.
    if (regeneratedNote) {
      print('note: binary updated, stub regenerated');
    }
    print(
      'behavior_id: ${record.behaviorId}\n'
      'source_criterion: ${record.sourceCriterion}\n'
      'kind: ${effectiveBehavior.kind.name}\n'
      'test_path: ${record.testPath}\n'
      'subject_path: ${record.subjectPath}\n'
      'runnable_test_name: ${record.runnableTestName}\n'
      'ownership: ${record.testOwnership.name}/${record.subjectOwnership.name}',
    );
    if (goldenPaths != null) {
      print(
        'golden_test_path: ${goldenPaths.laneTestPath}\n'
        'golden_fixtures_dir: ${goldenPaths.fixturesDir}',
      );
    }
    // Bug #840: the machine-readable JSON verdict — the final stdout line
    // on every gen path.
    _printVerdict(
      behaviorId: record.behaviorId,
      kind: effectiveBehavior.kind.name,
      golden: golden,
      verdict: adoptedPaths.isNotEmpty
          ? 'adopted'
          : dryRun
          ? 'planned'
          : record.testOwnership == Ownership.reused
          ? 'reused'
          : 'created',
      adopted: adoptedPaths,
      created: createdPaths,
      featureName: featureName,
      goldenTestPath: goldenPaths?.laneTestPath,
      goldenFixturesDir: goldenPaths?.fixturesDir,
    );
  }

  /// Emit the machine-readable JSON verdict (bug #840): the LAST stdout
  /// line, parseable by the recovery tooling, with the adopted/created
  /// split and the audit-log location for adopt runs.
  void _printVerdict({
    required String behaviorId,
    required String verdict,
    String? reason,
    List<String> adopted = const [],
    List<String> created = const [],
    String? featureName,
    // Bug #830: the effective subject kind and whether a golden baseline
    // hook was requested — additive fields, the recovery tooling parses
    // only the keys it knows.
    String? kind,
    bool golden = false,
    String? goldenTestPath,
    String? goldenFixturesDir,
  }) {
    print(
      jsonEncode({
        'command': 'gen',
        'behavior': behaviorId,
        'verdict': verdict,
        'reason': ?reason,
        'kind': ?kind,
        if (golden) 'golden': true,
        if (adopted.isNotEmpty) 'adopted': adopted,
        if (created.isNotEmpty) 'created': created,
        if (adopted.isNotEmpty && featureName != null)
          'audit_log': p.join('specs', featureName, 'tdd', 'audit.log'),
        'golden_test': ?goldenTestPath,
        'golden_fixtures': ?goldenFixturesDir,
      }),
    );
  }

  /// Writer selection by behavior kind (issue #841, issue #831):
  /// theme-kind behaviors get the theme-harness pair (`ThemeHarnessTestWriter`
  /// emitting the four-proof widget test — ShadTheme assertions under both
  /// ThemeModes, hardcoded-color audit, golden baselines, switch latency —
  /// and `ThemeHarnessSubjectWriter` emitting the subject contract);
  /// platform-kind behaviors (issue #831) get the platform-harness pair
  /// (certified-fake channel test + platform-channel subject stub) built
  /// from the resolved [PlatformHarnessContext]; every other kind gets the
  /// plain-function pair (spec 044). All pairs share the same `write`
  /// signatures so the transactional flow and the staleness re-render
  /// treat them identically.
  static _GenWriterPair _writersFor(
    Behavior behavior, {
    PlatformHarnessContext? platformContext,
  }) {
    if (behavior.kind == BehaviorKind.theme) {
      return (
        writeTest: const ThemeHarnessTestWriter().write,
        writeSubject: const ThemeHarnessSubjectWriter().write,
      );
    }
    if (behavior.kind == BehaviorKind.platform && platformContext != null) {
      return (
        writeTest: PlatformHarnessTestWriter(context: platformContext).write,
        writeSubject: PlatformHarnessSubjectWriter(
          context: platformContext,
        ).write,
      );
    }
    return (
      writeTest: const BehaviorTestWriter().write,
      writeSubject: const SubjectWriter().write,
    );
  }

  /// Resolve the platform-harness context for a platform-kind behavior
  /// (issue #831): the committed scenario + certified fake written by
  /// `zfa tdd fake <channel> --behavior <id>` must BOTH exist. A missing
  /// artifact or a schema violation is an honest refusal BEFORE any gen
  /// artifact is written, naming the exact remedy command.
  PlatformHarnessContext _resolvePlatformContext({
    required String cwd,
    required String featureDir,
    required String featureName,
    required String snakeId,
    required String behaviorId,
  }) {
    final scenarioPath = p.join(
      featureDir,
      'tdd',
      'scenarios',
      '$snakeId.json',
    );
    final scenarioFile = File(scenarioPath);
    if (!scenarioFile.existsSync()) {
      final scenarioRef = p.join(
        'specs',
        featureName,
        'tdd',
        'scenarios',
        '$snakeId.json',
      );
      stderr.writeln(
        'zfa tdd gen: platform behavior "$behaviorId" has no committed '
        'scenario at $scenarioRef. Generate the scenario + certified fake '
        'with `zfa tdd fake <channel> --behavior $behaviorId --feature '
        '$featureName`, commit the scenario as intent, then re-run gen '
        '(issue #831 — fakes replay committed intent, they are not '
        'agent-written).',
      );
      throw StateError(
        'zfa tdd gen: platform behavior "$behaviorId" has no committed '
        'scenario — run `zfa tdd fake <channel> --behavior $behaviorId '
        '--feature $featureName` first (issue #831)',
      );
    }
    final ChannelScenario scenario;
    try {
      final decoded =
          jsonDecode(scenarioFile.readAsStringSync()) as Map<String, Object?>;
      scenario = ChannelScenario.fromJson(decoded);
    } on ChannelScenarioException catch (e) {
      stderr.writeln(
        'zfa tdd gen: scenario at $scenarioPath violates the schema: $e '
        '(issue #831).',
      );
      throw StateError('zfa tdd gen: scenario schema violation — $e');
    } on FormatException catch (e) {
      stderr.writeln(
        'zfa tdd gen: scenario at $scenarioPath is not valid JSON: $e',
      );
      throw StateError('zfa tdd gen: scenario is not valid JSON — $e');
    }
    final fakePath = '$cwd/test/tdd/$featureName/fakes/${snakeId}_fake.dart';
    if (!File(fakePath).existsSync()) {
      stderr.writeln(
        'zfa tdd gen: platform behavior "$behaviorId" has a committed '
        'scenario but no certified fake at test/tdd/$featureName/fakes/'
        '${snakeId}_fake.dart. Re-run `zfa tdd fake <channel> --behavior '
        '$behaviorId --feature $featureName` to regenerate it (issue '
        '#831).',
      );
      throw StateError(
        'zfa tdd gen: platform behavior "$behaviorId" has no certified '
        'fake — run `zfa tdd fake <channel> --behavior $behaviorId '
        '--feature $featureName` first (issue #831)',
      );
    }
    return PlatformHarnessContext(
      scenario: scenario,
      slug: snakeId,
      fakeImport: 'fakes/${snakeId}_fake.dart',
      scenarioRef: p.join(
        'specs',
        featureName,
        'tdd',
        'scenarios',
        '$snakeId.json',
      ),
    );
  }

  /// Append the adoption audit record (bug #840): one JSONL line per
  /// adoption in `specs/<feature>/tdd/audit.log`.
  Future<void> _auditAdopt(
    String featureDir,
    String featureName,
    String behaviorId,
    List<String> adoptedPaths,
  ) async {
    final auditFile = File(p.join(featureDir, 'tdd', 'audit.log'));
    await auditFile.parent.create(recursive: true);
    final line = jsonEncode({
      'at': DateTime.now().toUtc().toIso8601String(),
      'action': 'adopt',
      'feature': featureName,
      'behavior': behaviorId,
      'paths': adoptedPaths,
    });
    final sink = auditFile.openWrite(mode: FileMode.append);
    sink.writeln(line);
    await sink.flush();
    await sink.close();
  }

  /// Detect a stub written by an OLDER binary (bug #683) and regenerate
  /// the pair when the current binary would render different content.
  /// Every awaited stage runs under the caller's shared [bounded]
  /// deadline (bug #744) — the staleness re-render is part of the bounded
  /// flow, not an unbounded tail.
  ///
  /// Option B (lenient):
  /// - the subject on disk no longer contains `UnimplementedError` → it
  ///   progressed past the stub stage (func scaffolding / implementation);
  ///   return false without touching anything;
  /// - the on-disk pair matches what the current binary would render →
  ///   return false and stay silent (FR-006 idempotency preserved);
  /// - otherwise the stub is stale → rewrite the pair with the current
  ///   writers, returning true so the caller prints the
  ///   `binary updated, stub regenerated` note. Ownership stays
  ///   `reused/reused`: the registry record is unchanged.
  ///
  /// Byte-comparison covers BOTH test and subject files (the writers are
  /// both a function of the generating binary — bug #683 covers a test
  /// half drift too). The current render is produced into a temp mirror
  /// under `<tmp>/test/tdd/<feature-slug>` + `<tmp>/lib/tdd/<feature-slug>`
  /// (the same namespaced structure as the real pair, bug #827) so the
  /// test's relative subject import resolves to a sibling on disk,
  /// byte-identical to a real `gen`. If the partial rewrite fails after
  /// touching one file, both files are restored to their pre-attempt bytes
  /// so a failed
  /// regeneration never leaves less on disk than before.
  Future<bool> _regenerateStaleStub({
    required Behavior behavior,
    required String featureName,
    required String testPath,
    required String subjectPath,
    required Future<T> Function<T>(Future<T> stage, String stageName) bounded,
    PlatformHarnessContext? platformContext,
  }) async {
    // Bug #835: an ffi harness is NEVER auto-regenerated. Its contract
    // seams are the implementer's wiring point — partial wiring (the
    // constants edited, a seam implemented) still contains
    // UnimplementedError, so the byte-compare below would clobber real
    // work (the same shape as the entity overwrite hazard). A stale
    // harness is self-consistent with its contract test (both generated
    // together), so the honest-red semantics survive untouched.
    if (behavior.kind == BehaviorKind.ffi) return false;
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) return false;
    final onDiskSubject = await bounded(
      subjectFile.readAsString(),
      'staleness: read on-disk subject',
    );
    // A progressed artifact is never clobbered by the staleness check.
    if (!onDiskSubject.contains('UnimplementedError')) return false;

    // Render the expected pair into a temp mirror (no real paths touched).
    // Bug #827: the mirror must reproduce the REAL relative test→subject
    // structure, not a hardcoded flat `test/tdd` + `lib/tdd` layout — the
    // rendered test imports its subject through a relative path computed
    // from the two paths, and a depth mismatch would make the byte
    // comparison report a false staleness (or mask a real one) for every
    // namespaced artifact.
    //
    // Writer dispatch by kind (issue #841): the mirror must render what
    // THIS binary would really write for the behavior's kind.
    final mirror = await Directory.systemTemp.createTemp('zfa_gen_stale_');
    try {
      final writers = _writersFor(behavior, platformContext: platformContext);
      final mirroredTest = p.join(
        mirror.path,
        'test',
        'tdd',
        featureName,
        p.basename(testPath),
      );
      final mirroredSubject = p.join(
        mirror.path,
        'lib',
        'tdd',
        featureName,
        p.basename(subjectPath),
      );
      await bounded(
        writers.writeTest(
          behavior: behavior,
          testPath: mirroredTest,
          subjectPath: mirroredSubject,
        ),
        'staleness: render current pair (test)',
      );
      await bounded(
        writers.writeSubject(behavior: behavior, subjectPath: mirroredSubject),
        'staleness: render current pair (subject)',
      );
      final expectedTest = await bounded(
        File(mirroredTest).readAsString(),
        'staleness: read rendered test',
      );
      final expectedSubject = await bounded(
        File(mirroredSubject).readAsString(),
        'staleness: read rendered subject',
      );
      final onDiskTest = await bounded(
        File(testPath).readAsString(),
        'staleness: read on-disk test',
      );
      if (expectedSubject == onDiskSubject && expectedTest == onDiskTest) {
        return false;
      }

      // Rewrite the real pair; roll back if either write fails so the
      // on-disk state is exactly what it was before this attempt.
      try {
        await bounded(
          File(testPath).writeAsString(expectedTest),
          'staleness: rewrite test file',
        );
        await bounded(
          File(subjectPath).writeAsString(expectedSubject),
          'staleness: rewrite subject file',
        );
      } catch (error) {
        // Best-effort rollback: restore the pre-attempt bytes. If even
        // the rollback fails (e.g. permissions flipped mid-flight), let
        // the original error propagate so the caller sees a real failure.
        // A bounded rollback past an expired deadline aborts before the
        // write starts (the flow is dead anyway; no unbounded I/O).
        try {
          await bounded(
            File(testPath).writeAsString(onDiskTest),
            'staleness: roll back test file',
          );
          await bounded(
            File(subjectPath).writeAsString(onDiskSubject),
            'staleness: roll back subject file',
          );
        } catch (_) {
          // Ignore rollback errors; surface the original failure.
        }
        rethrow;
      }
      return true;
    } finally {
      if (await mirror.exists()) await mirror.delete(recursive: true);
    }
  }

  Future<void> _deleteIfCreated(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Resolve a behavior id (e.g. `A1`, `B-003` or `U1`) by scanning feature
  /// `test-list.md` files through the shared [TestListReader] — the single
  /// format contract (bug #617). If [featureFlag] is set, only that feature
  /// is scanned. Otherwise, all features are scanned and the first match in
  /// alphabetical order wins, with a preference for
  /// `044-test-tdd-generation` (the feature this command lives under).
  ///
  /// Returns a null behavior when no row matches; a malformed list surfaces
  /// as a [TestListReadException] (honest stop naming the line, FR-011).
  Future<(Behavior?, String, String)> _resolveBehavior(
    String cwd,
    String behaviorId,
    String? featureFlag,
  ) async {
    final specsDir = Directory('$cwd/specs');
    if (!await specsDir.exists()) return (null, '', '');

    if (featureFlag != null && featureFlag.isNotEmpty) {
      // Only scan the specified feature.
      final featureDir = '$cwd/specs/$featureFlag';
      final testListFile = File('$featureDir/tdd/test-list.md');
      if (await testListFile.exists()) {
        final behavior = await _findRow(featureDir, featureFlag, behaviorId);
        if (behavior != null) return (behavior, featureDir, featureFlag);
      }
      return (null, '', '');
    }

    // No --feature given: scan all feature dirs and reject ambiguous IDs.
    final matches = <(Behavior, String, String)>[];
    final dirs = <Directory>[];
    await for (final entity in specsDir.list()) {
      if (entity is Directory) dirs.add(entity);
    }
    dirs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    for (final entity in dirs) {
      final featureName = p.basename(entity.path);
      final testListFile = File('${entity.path}/tdd/test-list.md');
      if (!await testListFile.exists()) continue;
      final behavior = await _findRow(entity.path, featureName, behaviorId);
      if (behavior != null) {
        matches.add((behavior, entity.path, featureName));
      }
    }
    if (matches.isEmpty) return (null, '', '');
    if (matches.length > 1) {
      final features = matches.map((m) => m.$3).join(', ');
      stderr.writeln(
        'zfa tdd gen: ambiguous behavior id "$behaviorId" found in '
        'multiple features: $features. Use --feature to disambiguate.',
      );
      throw StateError(
        'zfa tdd gen: ambiguous behavior id "$behaviorId" in $features',
      );
    }
    return matches.first;
  }

  /// First row with [behaviorId] in the feature's test list, mapped onto
  /// [Behavior] via the shared reader's contract.
  Future<Behavior?> _findRow(
    String featureDir,
    String featureName,
    String behaviorId,
  ) async {
    final rows = await TestListReader(featureDir).read();
    for (final row in rows) {
      if (row.id != behaviorId) continue;
      return Behavior(
        id: row.id,
        feature: featureName,
        kind: row.kind,
        description: row.description,
        sourceCriterion: row.traces,
        target: row.target,
        persistence: row.persistence,
      );
    }
    return null;
  }

  /// Validate the required fields (FR-002).
  List<String> _missingRequiredFields(Behavior b) {
    final missing = <String>[];
    if (b.id.isEmpty) missing.add('behavior id');
    if (b.description.isEmpty) missing.add('description');
    if (b.sourceCriterion.isEmpty) missing.add('source criterion');
    if (b.target.isEmpty) missing.add('target');
    return missing;
  }

  String _toSnakeCase(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }

  /// The feature name lands inside the artifact path (bug #827): keep it a
  /// single plain directory segment (mirrors compose/make/verify-red's
  /// `--feature` validation) so a hostile or malformed feature name cannot
  /// escape the `test/tdd/<feature-slug>/` namespace.
  void _validateFeatureSegment(String feature) {
    if (feature.contains('/') ||
        feature.contains(r'\') ||
        feature == '.' ||
        feature == '..' ||
        feature.isEmpty) {
      throw StateError(
        'zfa tdd gen: invalid feature "$feature": expected a single spec '
        'directory name such as 044-test-tdd-generation, not a path.',
      );
    }
  }
}

/// The wall-clock deadline shared by every awaited stage of one gen flow
/// (bug #744 — the budget, enforced INSIDE the flow so the transactional
/// cleanup and the stage-boundary aborts work as designed).
class _FlowDeadline {
  _FlowDeadline(this.budget) : _startedAt = DateTime.now();

  /// The total budget the flow was given.
  final Duration budget;

  final DateTime _startedAt;

  /// Time left before the budget expires (never negative). A zero
  /// remaining budget makes [Future.timeout] fire immediately, so an
  /// abandoned continuation aborts at its next stage boundary.
  Duration remaining() {
    final left = budget - DateTime.now().difference(_startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the budget has already been exhausted.
  bool get expired => remaining() == Duration.zero;
}

/// Thrown from INSIDE the gen flow when a stage outlives the shared
/// deadline (bug #744 hardening). Throwing inside — not from a wrapper —
/// is the point: the flow's transactional cleanup (remove what this
/// attempt created) runs before the classification surfaces, so a
/// timed-out gen cannot leave an orphan artifact that would poison the
/// next run with an FR-008 ownership conflict.
class _GenFlowTimeout implements Exception {
  _GenFlowTimeout(this.stage);

  /// The flow stage that outlived the budget.
  final String stage;

  @override
  String toString() => 'gen flow timed out at the "$stage" stage';
}

/// The kind-selected writer pair for one gen flow (issue #841): the two
/// writer tear-offs, so the write path and the staleness re-render share
/// one dispatch decision. Both theme-harness writers expose the same
/// `write` signatures as the plain-function pair.
typedef _GenWriterPair = ({
  Future<void> Function({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
    bool golden,
  })
  writeTest,
  Future<void> Function({
    required Behavior behavior,
    required String subjectPath,
  })
  writeSubject,
});
