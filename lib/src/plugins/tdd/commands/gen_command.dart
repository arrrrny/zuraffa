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
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/behavior_test_writer.dart';
import '../services/subject_writer.dart';
import '../services/test_list_reader.dart';
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
  String get invocation => 'zfa tdd gen <behavior-id> [--dry-run]';

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
    final featureFlag = argResults!['feature'] as String?;
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults!['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();
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
      stderr.writeln(
        'zfa tdd gen: unknown behavior id "$behaviorId". '
        'No matching row found in any specs/<feature>/tdd/test-list.md'
        '${featureFlag != null ? " for feature $featureFlag" : ""}.',
      );
      throw StateError('zfa tdd gen: unknown behavior id "$behaviorId"');
    }

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
    final runnableTestName =
        '$testPath::${behavior.id}::${behavior.description}';

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

    try {
      record = await bounded(
        registry.preflight(record, dryRun: dryRun),
        'ownership preflight',
      );
    } on OwnershipConflict catch (e) {
      stderr.writeln('zfa tdd gen: ownership conflict — $e');
      throw StateError('zfa tdd gen: ownership conflict — $e');
    }

    // Write a new pair transactionally from the command's perspective. Any
    // writer or registry failure removes artifacts created by this attempt.
    if (record.testOwnership != Ownership.reused && !dryRun) {
      try {
        final testWriter = const BehaviorTestWriter();
        await bounded(
          testWriter.write(
            behavior: behavior,
            testPath: testPath,
            subjectPath: subjectPath,
          ),
          'write test file',
        );
        final subjectWriter = const SubjectWriter();
        await bounded(
          subjectWriter.write(behavior: behavior, subjectPath: subjectPath),
          'write subject file',
        );
        record = await bounded(registry.append(record), 'registry append');
      } catch (error, stackTrace) {
        // Transactional cleanup: remove what THIS attempt created. The
        // timeout path is included by construction — the deadline fires
        // inside the flow, so _GenFlowTimeout is caught here like any
        // other failure (the pre-hardening #748 wrapper-level .timeout()
        // bypassed this catch entirely and could leave an orphan file
        // that poisons the next run with an FR-008 ownership conflict).
        await _deleteIfCreated(testPath);
        await _deleteIfCreated(subjectPath);
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
          await _deleteIfCreated(testPath);
          await _deleteIfCreated(subjectPath);
        }
        Error.throwWithStackTrace(error, stackTrace);
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
        behavior: behavior,
        featureName: featureName,
        testPath: testPath,
        subjectPath: subjectPath,
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
      'test_path: ${record.testPath}\n'
      'subject_path: ${record.subjectPath}\n'
      'runnable_test_name: ${record.runnableTestName}\n'
      'ownership: ${record.testOwnership.name}/${record.subjectOwnership.name}',
    );
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
  }) async {
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
    final mirror = await Directory.systemTemp.createTemp('zfa_gen_stale_');
    try {
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
        const BehaviorTestWriter().write(
          behavior: behavior,
          testPath: mirroredTest,
          subjectPath: mirroredSubject,
        ),
        'staleness: render current pair (test)',
      );
      await bounded(
        const SubjectWriter().write(
          behavior: behavior,
          subjectPath: mirroredSubject,
        ),
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
