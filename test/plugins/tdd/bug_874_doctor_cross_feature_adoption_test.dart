@Tags(['slow'])
// Bug #874 — tdd doctor mis-prescribes cross-feature adoption + the
// foreign-owned guardrail for gen's recovery path.
//
// RED evidence: after #827 namespacing, a project whose FIRST feature was
// completed on the pre-fix binary carries legacy flat artifacts owned by
// that feature's registry. Running `zfa tdd doctor <second-feature>` scans
// the flat layout, finds the first feature's files, and — consulting only
// the QUERIED feature's registry — declares them "unowned" and prescribes
// `zfa tdd gen <id> --adopt --feature <second-feature>` for all of them.
// Following the prescription would register another feature's files into
// the second registry (two features owning one file) — the exact trust
// violation the ownership guardrails exist to prevent.
//
// Contract under test:
// 1. Doctor (and gen's recovery path) consult ALL specs/*/tdd/artifacts.json
//    before declaring a file "unowned". Another feature's file → distinct
//    verdict `foreign-owned`, prescription `migrate`, NEVER `adopt`.
// 2. The migration fix is `zfa tdd migrate-paths <owner>` (the command
//    exists on master; the owner's registry is the one that must move).
// 3. Doctor verdicts include the owning feature for foreign files
//    (`owned_by` map + owner named in the drift lines).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  /// The queried feature (post-#827 binary, namespaced artifacts).
  const feature = '004-dependency-injection';

  /// The pre-#827 feature whose legacy flat artifacts live at
  /// test/tdd/<id>_test.dart and are OWNED by its registry.
  const owner = '001-app-bootstrap';

  /// A second pre-#827 owner (multi-owner case).
  const owner2 = '002-cache-adapter';

  const foreignId = 'A3';

  Future<String> runCli(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', ...args, '--project', fx.root.path]);
  }

  /// The last non-empty stdout line — the recovery commands' JSON verdict
  /// contract (bug #840).
  Map<String, dynamic> verdict(String out) {
    final lines = out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }

  /// The `--> fix:` line's payload, for assertions that must not be
  /// sensitive to trailing explanation text.
  String fixLine(String out) => out
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.startsWith('--> fix:'))
      .substring('--> fix:'.length)
      .trim();

  Behavior foreignBehavior(String forFeature) => Behavior(
    id: foreignId,
    feature: forFeature,
    kind: BehaviorKind.unit,
    description: 'resolves a dependency by contract',
    sourceCriterion: 'FR-003',
    target: 'subjectUnderTest',
  );

  String snakeOf(String id) =>
      id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  String relFromRoot(String path) =>
      p.relative(path, from: fx.root.path).replaceAll(r'\', '/');

  String flatTestPath(String id) =>
      p.join(fx.root.path, 'test', 'tdd', '${snakeOf(id)}_test.dart');

  String flatSubjectPath(String id) =>
      p.join(fx.root.path, 'lib', 'tdd', '${snakeOf(id)}_subject.dart');

  String namespacedTestPath(String id, String forFeature) => p.join(
    fx.root.path,
    'test',
    'tdd',
    forFeature,
    '${snakeOf(id)}_test.dart',
  );

  String namespacedSubjectPath(String id, String forFeature) => p.join(
    fx.root.path,
    'lib',
    'tdd',
    forFeature,
    '${snakeOf(id)}_subject.dart',
  );

  /// Write the generated-shape pair for [id] at [testPath]/[subjectPath]
  /// and record OWNERSHIP in [ownerFeature]'s registry — the state the
  /// issue's repro creates (a completed pre-#827 feature). With
  /// [relativeRecord], the registry records project-relative paths (the
  /// recorded path form is not guaranteed either way; the ownership
  /// lookup must normalize).
  Future<void> seedForeignOwnedPair({
    required String ownerFeature,
    required String id,
    required String testPath,
    required String subjectPath,
    bool relativeRecord = false,
  }) async {
    final behavior = foreignBehavior(ownerFeature);
    await const BehaviorTestWriter().write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    await const SubjectWriter().write(
      behavior: behavior,
      subjectPath: subjectPath,
    );
    final recordedTest = relativeRecord ? relFromRoot(testPath) : testPath;
    final recordedSubject = relativeRecord
        ? relFromRoot(subjectPath)
        : subjectPath;
    final regDir = Directory(
      p.join(fx.root.path, 'specs', ownerFeature, 'tdd'),
    );
    await regDir.create(recursive: true);
    await File(p.join(regDir.path, 'artifacts.json')).writeAsString(
      jsonEncode({
        'feature': ownerFeature,
        'records': [
          {
            'behavior_id': id,
            'feature': ownerFeature,
            'source_criterion': 'FR-003',
            'test_path': recordedTest,
            'subject_path': recordedSubject,
            'runnable_test_name': '$recordedTest::$id::resolved',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-08-30T00:00:00.000Z',
          },
        ],
      }),
    );
  }

  /// Write the generated-shape pair for [id] at [testPath]/[subjectPath]
  /// with NO registry record anywhere — the genuinely unowned state
  /// (post-crash orphan) the #840 adopt prescription targets.
  Future<void> seedUnownedPair({
    required String id,
    required String testPath,
    required String subjectPath,
  }) async {
    final behavior = Behavior(
      id: id,
      feature: feature,
      kind: BehaviorKind.unit,
      description: 'returns 42 when invoked with no args',
      sourceCriterion: 'FR-001',
      target: 'subjectUnderTest',
    );
    await const BehaviorTestWriter().write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    await const SubjectWriter().write(
      behavior: behavior,
      subjectPath: subjectPath,
    );
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('bug 874: zfa tdd doctor <feature> cross-registry awareness', () {
    test('doctor prescribes migrate (never adopt) for another feature\'s '
        'flat artifacts — the issue repro', () async {
      // Feature 001 completed pre-#827: its flat pair is OWNED by 001's
      // registry. Doctor for 004 must NOT call it unowned.
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: flatTestPath(foreignId),
        subjectPath: flatSubjectPath(foreignId),
      );

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('foreign-owned'), reason: out);
      final fix = fixLine(out);
      expect(fix, contains('zfa tdd migrate-paths $owner'), reason: out);
      // The trust violation: never prescribe adopting another feature's
      // files into the queried registry.
      expect(fix, isNot(contains('--adopt')), reason: out);
      final v = verdict(out);
      expect(v['command'], 'doctor', reason: out);
      expect(v['verdict'], 'foreign-owned', reason: out);
      expect(v['prescription'], 'migrate', reason: out);
    });

    test('verdict includes the owning feature for foreign files '
        '(requirement 3)', () async {
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: flatTestPath(foreignId),
        subjectPath: flatSubjectPath(foreignId),
      );

      final out = await runCli(['doctor', feature]);

      final v = verdict(out);
      final ownedBy = v['owned_by'] as Map<String, dynamic>;
      expect(ownedBy[relFromRoot(flatTestPath(foreignId))], owner, reason: out);
      expect(
        ownedBy[relFromRoot(flatSubjectPath(foreignId))],
        owner,
        reason: out,
      );
      // The drift line names the owner too.
      expect(out, contains('owned by $owner'), reason: out);
    });

    test('relative-path registry records still resolve to their owner '
        '(normalization)', () async {
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: flatTestPath(foreignId),
        subjectPath: flatSubjectPath(foreignId),
        relativeRecord: true,
      );

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      final v = verdict(out);
      expect(v['verdict'], 'foreign-owned', reason: out);
      expect(v['prescription'], 'migrate', reason: out);
      final fix = fixLine(out);
      expect(fix, contains('zfa tdd migrate-paths $owner'), reason: out);
    });

    test('multiple foreign owners -> the all-features migration', () async {
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: 'A3',
        testPath: flatTestPath('A3'),
        subjectPath: flatSubjectPath('A3'),
      );
      await seedForeignOwnedPair(
        ownerFeature: owner2,
        id: 'B7',
        testPath: flatTestPath('B7'),
        subjectPath: flatSubjectPath('B7'),
      );

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      final v = verdict(out);
      expect(v['verdict'], 'foreign-owned', reason: out);
      final fix = fixLine(out);
      // Two owners: no single feature's migration suffices.
      expect(fix, contains('zfa tdd migrate-paths'), reason: out);
      expect(fix, isNot(contains('migrate-paths $owner')), reason: out);
      expect(fix, isNot(contains('migrate-paths $owner2')), reason: out);
      final ownedBy = v['owned_by'] as Map<String, dynamic>;
      expect(ownedBy.length, 4, reason: out);
    });

    test('a genuinely unowned flat file still prescribes adopt '
        '(#840 control)', () async {
      // Nobody's registry records the pair — the post-crash orphan.
      await seedUnownedPair(
        id: 'C1',
        testPath: flatTestPath('C1'),
        subjectPath: flatSubjectPath('C1'),
      );

      final out = await runCli(['doctor', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('--adopt'), reason: out);
      final v = verdict(out);
      expect(v['verdict'], 'drift', reason: out);
      expect(v['prescription'], 'adopt', reason: out);
    });

    test(
      'foreign-owned takes precedence over a same-run unowned finding',
      () async {
        // 001's flat pair (foreign) + a nobody's orphan (unowned): one
        // deterministic prescription — migrate first, adopt is re-run's
        // finding afterwards.
        await seedForeignOwnedPair(
          ownerFeature: owner,
          id: foreignId,
          testPath: flatTestPath(foreignId),
          subjectPath: flatSubjectPath(foreignId),
        );
        await seedUnownedPair(
          id: 'C1',
          testPath: flatTestPath('C1'),
          subjectPath: flatSubjectPath('C1'),
        );

        final out = await runCli(['doctor', feature]);

        expect(exitCode, 1, reason: out);
        final v = verdict(out);
        expect(v['verdict'], 'foreign-owned', reason: out);
        expect(v['prescription'], 'migrate', reason: out);
        final fix = fixLine(out);
        expect(fix, contains('zfa tdd migrate-paths $owner'), reason: out);
        expect(fix, isNot(contains('--adopt')), reason: out);
      },
    );

    test('the owning feature\'s own doctor run stays healthy', () async {
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: flatTestPath(foreignId),
        subjectPath: flatSubjectPath(foreignId),
      );

      final out = await runCli(['doctor', owner]);

      expect(exitCode, 0, reason: out);
      final v = verdict(out);
      expect(v['verdict'], 'healthy', reason: out);
      expect(v['prescription'], 'none', reason: out);
    });
  });

  group('bug 874: zfa tdd gen recovery path refuses foreign-owned files', () {
    Future<List<int>> fileBytes(String path) => File(path).readAsBytes();

    test('--adopt refuses to register a file another feature owns', () async {
      // 001's registry owns the file at 004's NAMESPACED path (the
      // corrupted-handoff state doctor's old fix line could steer into).
      // gen --adopt for 004 must refuse, not register it into 004.
      final testPath = namespacedTestPath(foreignId, feature);
      final subjectPath = namespacedSubjectPath(foreignId, feature);
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      await fx.seedTestList([
        (
          id: foreignId,
          description: 'resolves a dependency by contract',
          traces: 'FR-003',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      final before = await fileBytes(testPath);

      final out = await runCli([
        'gen',
        foreignId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 1, reason: out);
      final v = verdict(out);
      expect(v['command'], 'gen', reason: out);
      expect(v['verdict'], 'foreign-owned', reason: out);
      expect(out, contains('zfa tdd migrate-paths'), reason: out);
      // Nothing was registered into 004, nothing was rewritten.
      expect(File(fx.artifactsPath).existsSync(), isFalse, reason: out);
      expect(await fileBytes(testPath), before, reason: out);
    });

    test('plain gen (no --adopt) also reports foreign-owned, not just '
        'a generic ownership conflict', () async {
      final testPath = namespacedTestPath(foreignId, feature);
      final subjectPath = namespacedSubjectPath(foreignId, feature);
      await seedForeignOwnedPair(
        ownerFeature: owner,
        id: foreignId,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      await fx.seedTestList([
        (
          id: foreignId,
          description: 'resolves a dependency by contract',
          traces: 'FR-003',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await runCli(['gen', foreignId, '--feature', feature]);

      expect(exitCode, 1, reason: out);
      expect(out, contains('"verdict":"foreign-owned"'), reason: out);
      expect(out, contains(owner), reason: out);
      expect(File(fx.artifactsPath).existsSync(), isFalse, reason: out);
    });

    test(
      '--adopt still adopts a genuinely unowned file (#840 control)',
      () async {
        final testPath = namespacedTestPath(foreignId, feature);
        final subjectPath = namespacedSubjectPath(foreignId, feature);
        await seedUnownedPair(
          id: foreignId,
          testPath: testPath,
          subjectPath: subjectPath,
        );
        await fx.seedTestList([
          (
            id: foreignId,
            description: 'resolves a dependency by contract',
            traces: 'FR-003',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);

        final out = await runCli([
          'gen',
          foreignId,
          '--feature',
          feature,
          '--adopt',
        ]);

        expect(exitCode, 0, reason: out);
        final v = verdict(out);
        expect(v['verdict'], 'adopted', reason: out);
      },
    );

    test('--adopt with a prior record in THIS feature still refuses '
        '(nothing unowned to adopt — control)', () async {
      // 004's own record exists; the conflict is a registry/paths
      // disagreement inside ONE feature — never a foreign-owned case.
      await fx.registerBehavior(
        id: foreignId,
        description: 'resolves a dependency by contract',
        writeTestFile: false,
      );
      await fx.seedTestList([
        (
          id: foreignId,
          description: 'resolves a dependency by contract',
          traces: 'FR-003',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      final out = await runCli([
        'gen',
        foreignId,
        '--feature',
        feature,
        '--adopt',
      ]);

      expect(exitCode, 1, reason: out);
      // This refusal path throws StateError after the verdict (the runner
      // appends the ❌ Error line), so assert on the payload, not on the
      // last-line parse.
      expect(out, contains('"verdict":"refused"'), reason: out);
      expect(out, isNot(contains('"verdict":"foreign-owned"')), reason: out);
    });
  });
}
