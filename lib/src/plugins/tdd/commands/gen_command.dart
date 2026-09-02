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
///      behavior. Path convention: `test/tdd/<snake-id>_test.dart` and
///      `lib/tdd/<snake-id>_subject.dart`.
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
/// append, and the staleness re-render — runs under ONE wall-clock budget
/// (`--timeout`, default 30s; the same acceptance budget the #744 records
/// name). This applies the #742 timeout pattern to the gen step as a
/// safety net regardless of the exact stall trigger: a stage that waits
/// indefinitely (the recorded "hangs until SIGKILL" failure mode) now
/// stops the command at the budget with a classification naming the
/// behavior, step, and `outcome=timeout`, and a non-zero exit — never a
/// silent infinite hang. The flow spawns NO subprocess of its own (test
/// execution is verify-red/make's contract, not gen's), so the budget
/// needs no process-kill side effects. The flow also depends only on the
/// test-list row, the registry, and the pair on disk — never on run-state
/// or suite health — so a DEFERRED/unexpressible predecessor (A1 red at
/// its phase-2 make, bug #625/#657) cannot block a later gen (A2): the
/// #738-era deadlock inspection found no cross-behavior wait in this
/// flow, and the budget caps whatever could stall.
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
          'Wall-clock budget for the whole gen flow, in seconds (bug #744: '
          'the #742 timeout pattern applied to gen as a safety net). On '
          'expiry the command stops with outcome=timeout and a non-zero '
          'exit instead of hanging indefinitely.',
      defaultsTo: '$defaultTimeoutSeconds',
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

  /// The default wall-clock budget for the whole gen flow, in seconds
  /// (bug #744 — the same acceptance budget the bug records name:
  /// "A2 completes within 30s").
  static const int defaultTimeoutSeconds = 30;

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
    final timeoutSeconds = _parseTimeoutSeconds();
    final budget = Duration(seconds: timeoutSeconds);

    // Bug #744: the WHOLE flow runs under one wall-clock budget. A stage
    // that waits indefinitely — the recorded failure mode (the command
    // hung until SIGKILL) — stops here at the budget with an honest
    // misfire-stop classification (#742 pattern applied to gen) instead
    // of hanging. gen spawns no subprocess of its own, so no process-kill
    // side effects are needed: a timed-out stage's pending I/O is simply
    // abandoned as the process exits.
    try {
      await _generate(
        behaviorId,
        dryRun: dryRun,
        featureFlag: featureFlag,
        cwd: cwd,
      ).timeout(budget);
    } on TimeoutException {
      stderr.writeln(
        'zfa tdd gen: timeout after ${timeoutSeconds}s — behavior='
        '$behaviorId step=gen outcome=timeout',
      );
      stderr.writeln(
        '   a gen stage exceeded its wall-clock budget and was stopped '
        'before it could hang (bug #742/#744 safety net). Re-run with '
        '--timeout <seconds> to raise the budget.',
      );
      throw StateError(
        'zfa tdd gen: timeout after ${timeoutSeconds}s — behavior='
        '$behaviorId step=gen outcome=timeout',
      );
    }
  }

  /// The unbounded-shaped flow body, verbatim the pre-#744 contract:
  /// resolve → preflight → write → register → (staleness check) → print.
  /// Bounded by [run]'s budget.
  Future<void> _generate(
    String behaviorId, {
    required bool dryRun,
    required String? featureFlag,
    required String cwd,
  }) async {
    // Resolve the behavior. If --feature is set, only scan that one
    // feature's test-list. Otherwise, scan all features and prefer
    // `044-test-tdd-generation` (the feature this command lives under).
    // A malformed test list stops honestly naming the line (FR-011) —
    // never silently skipped (the anti-pattern behind bug #617).
    final (Behavior?, String, String)? resolved;
    try {
      resolved = await _resolveBehavior(cwd, behaviorId, featureFlag);
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

    // Compute paths.
    final snakeId = _toSnakeCase(behavior.id);
    final testPath = '$cwd/test/tdd/${snakeId}_test.dart';
    final subjectPath = '$cwd/lib/tdd/${snakeId}_subject.dart';
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
      record = await registry.preflight(record, dryRun: dryRun);
    } on OwnershipConflict catch (e) {
      stderr.writeln('zfa tdd gen: ownership conflict — $e');
      throw StateError('zfa tdd gen: ownership conflict — $e');
    }

    // Write a new pair transactionally from the command's perspective. Any
    // writer or registry failure removes artifacts created by this attempt.
    if (record.testOwnership != Ownership.reused && !dryRun) {
      try {
        final testWriter = const BehaviorTestWriter();
        await testWriter.write(
          behavior: behavior,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        final subjectWriter = const SubjectWriter();
        await subjectWriter.write(behavior: behavior, subjectPath: subjectPath);
        record = await registry.append(record);
      } catch (error, stackTrace) {
        await _deleteIfCreated(testPath);
        await _deleteIfCreated(subjectPath);
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
        testPath: testPath,
        subjectPath: subjectPath,
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

  /// Parse the `--timeout` value (seconds). A non-integer or a value
  /// that is not positive is a usage error.
  int _parseTimeoutSeconds() {
    final raw = argResults!['timeout'] as String?;
    if (raw == null || raw.trim().isEmpty) {
      return defaultTimeoutSeconds;
    }
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) {
      usageException(
        'zfa tdd gen: --timeout must be a positive integer (seconds), '
        'got "$raw".',
      );
    }
    return parsed;
  }

  /// Detect a stub written by an OLDER binary (bug #683) and regenerate
  /// the pair when the current binary would render different content.
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
  /// under `<tmp>/test/tdd` + `<tmp>/lib/tdd` so the test's relative
  /// subject import resolves to a sibling on disk, byte-identical to a
  /// real `gen`. If the partial rewrite fails after touching one file,
  /// both files are restored to their pre-attempt bytes so a failed
  /// regeneration never leaves less on disk than before.
  Future<bool> _regenerateStaleStub({
    required Behavior behavior,
    required String testPath,
    required String subjectPath,
  }) async {
    final subjectFile = File(subjectPath);
    if (!await subjectFile.exists()) return false;
    final onDiskSubject = await subjectFile.readAsString();
    // A progressed artifact is never clobbered by the staleness check.
    if (!onDiskSubject.contains('UnimplementedError')) return false;

    // Render the expected pair into a temp mirror (no real paths touched).
    final mirror = await Directory.systemTemp.createTemp('zfa_gen_stale_');
    try {
      final mirroredTest = p.join(
        mirror.path,
        'test',
        'tdd',
        p.basename(testPath),
      );
      final mirroredSubject = p.join(
        mirror.path,
        'lib',
        'tdd',
        p.basename(subjectPath),
      );
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: mirroredTest,
        subjectPath: mirroredSubject,
      );
      await const SubjectWriter().write(
        behavior: behavior,
        subjectPath: mirroredSubject,
      );
      final expectedTest = await File(mirroredTest).readAsString();
      final expectedSubject = await File(mirroredSubject).readAsString();
      final onDiskTest = await File(testPath).readAsString();
      if (expectedSubject == onDiskSubject && expectedTest == onDiskTest) {
        return false;
      }

      // Rewrite the real pair; roll back if either write fails so the
      // on-disk state is exactly what it was before this attempt.
      try {
        await File(testPath).writeAsString(expectedTest);
        await File(subjectPath).writeAsString(expectedSubject);
      } catch (error) {
        // Best-effort rollback: restore the pre-attempt bytes. If even
        // the rollback fails (e.g. permissions flipped mid-flight), let
        // the original error propagate so the caller sees a real failure.
        try {
          await File(testPath).writeAsString(onDiskTest);
          await File(subjectPath).writeAsString(onDiskSubject);
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
}
