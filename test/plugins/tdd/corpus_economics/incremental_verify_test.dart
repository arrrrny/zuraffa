// Spec 069-corpus-economics — T001: incremental verification.
//
// The refactor re-proof currently runs the FULL suite after every pass
// application (the 9m30s "ONE refactor" cost in issue #916: two full-suite
// runs + build). This file pins the incremental contract:
//
//   1. PassRegistryTracker records the pass-registry-changed files
//      (specs/<feature>/tdd/pass-registry.json) — fail-safe reads.
//   2. The changed files map to covering tests through the feature's
//      artifact registry; a changed file that maps to no registered
//      artifact is UNATTRIBUTABLE and must signal the full-suite
//      fallback (never a silently narrowed re-proof).
//   3. `zfa tdd refactor` scopes its RE-PROOF run to the covering tests
//      of the changed files (default); `--full-reproof` forces the full
//      suite (the feature-completion / nightly full gate).
//
// Fast tier: the suite runner is a spy script emitting a package:test-
// shaped green transcript — no `dart test` subprocess is compiled. The
// pass registry runs the real `dart format lib/` over a malformed
// (registered) subject, exactly like the production flow.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/artifact_record.dart';
import 'package:zuraffa/src/plugins/tdd/models/ownership.dart';
import 'package:zuraffa/src/plugins/tdd/services/pass_registry_tracker.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  const feature = '090-incremental-verify';
  late String fakeZfa;
  late String suiteSpy;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
    suiteSpy = await fx.writeSpyScript(
      'suite',
      output: TddFixture.greenSuiteTranscript,
    );
    await fx.rewriteProfile(
      singleTemplate: '$suiteSpy {file} {name}',
      suiteTemplate: suiteSpy,
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('PassRegistryTracker — persistence (T001 unit)', () {
    test(
      'record() writes pass-registry.json and read() round-trips it',
      () async {
        final tracker = PassRegistryTracker(featureDir: fx.featureDir);
        final path = await tracker.record(
          changedFiles: const ['lib/b_001_subject.dart'],
          capturedAt: '2026-09-03T00:00:00.000Z',
          command: 'dart format lib/',
        );

        expect(path, p.join(fx.featureDir, 'tdd', 'pass-registry.json'));
        final snapshot = await PassRegistryTracker.read(path);
        expect(snapshot, isNotNull);
        expect(snapshot!.entries, hasLength(1));
        expect(snapshot.entries.first.files, ['lib/b_001_subject.dart']);
        expect(snapshot.entries.first.command, 'dart format lib/');
        expect(snapshot.entries.first.capturedAt, '2026-09-03T00:00:00.000Z');
      },
    );

    test('record() accumulates entries (append, not overwrite)', () async {
      final tracker = PassRegistryTracker(featureDir: fx.featureDir);
      await tracker.record(
        changedFiles: const ['lib/a_subject.dart'],
        capturedAt: '2026-09-03T00:00:00.000Z',
      );
      await tracker.record(
        changedFiles: const ['lib/b_subject.dart'],
        capturedAt: '2026-09-03T00:01:00.000Z',
      );

      final snapshot = await PassRegistryTracker.read(
        PassRegistryTracker.pathFor(featureDir: fx.featureDir),
      );
      expect(snapshot!.entries, hasLength(2));
      // The union of changed files across entries.
      expect(snapshot.unionChangedFiles(), {
        'lib/a_subject.dart',
        'lib/b_subject.dart',
      });
    });

    test(
      'read() is fail-safe: missing file and corrupt JSON yield null',
      () async {
        expect(
          await PassRegistryTracker.read(p.join(fx.root.path, 'nope.json')),
          isNull,
        );
        final corrupt = p.join(fx.root.path, 'corrupt.json');
        await File(corrupt).writeAsString('{not json');
        expect(await PassRegistryTracker.read(corrupt), isNull);
        // A shape-valid JSON object with the wrong schema is also null.
        final wrongShape = p.join(fx.root.path, 'wrong.json');
        await File(wrongShape).writeAsString(jsonEncode({'nope': 1}));
        expect(await PassRegistryTracker.read(wrongShape), isNull);
      },
    );
  });

  group('PassRegistryTracker — covering-tests mapping (T001 unit)', () {
    String snake(String id) => id.toLowerCase().replaceAll('-', '_');

    ArtifactRecord recordFor(String id, String description) => ArtifactRecord(
      behaviorId: id,
      feature: feature,
      sourceCriterion: 'FR-007',
      testPath: p.join(fx.root.path, 'test', 'tdd', '${snake(id)}_test.dart'),
      subjectPath: p.join(
        fx.root.path,
        'lib',
        'tdd',
        '${snake(id)}_subject.dart',
      ),
      runnableTestName: 'runnable $id',
      testOwnership: Ownership.created,
      subjectOwnership: Ownership.created,
      createdAt: '2026-09-03T00:00:00.000Z',
    );

    test('a changed registered subject maps to its covering test '
        '(absolute registry paths normalized against the project root)', () {
      final covering = PassRegistryTracker.coveringTestsFor(
        changedFiles: {
          p.join(fx.root.path, 'lib', 'tdd', 'b_001_subject.dart'),
        },
        artifacts: [recordFor('B-001', 'first')],
        projectRoot: fx.root.path,
      );
      // The covering set is the record's test path, normalized to the
      // project-relative form (absolute registry path in, relative out).
      expect(covering, {p.posix.join('test', 'tdd', 'b_001_test.dart')});
      // Relative changed paths map identically (tree-snapshot form).
      final coveringRelative = PassRegistryTracker.coveringTestsFor(
        changedFiles: {'lib/tdd/b_001_subject.dart'},
        artifacts: [recordFor('B-001', 'first')],
        projectRoot: fx.root.path,
      );
      expect(coveringRelative, covering);
    });

    test('a changed file that is no registered artifact maps to NOTHING '
        '(the full-suite fallback signal)', () {
      final covering = PassRegistryTracker.coveringTestsFor(
        changedFiles: {'lib/unregistered.dart'},
        artifacts: [recordFor('B-001', 'first')],
        projectRoot: fx.root.path,
      );
      expect(covering, isEmpty);
    });

    test('one unattributable file poisons the whole set — never a '
        'silently narrowed re-proof', () {
      final covering = PassRegistryTracker.coveringTestsFor(
        changedFiles: {
          'lib/tdd/b_001_subject.dart',
          'lib/tdd/unregistered.dart',
        },
        artifacts: [recordFor('B-001', 'first')],
        projectRoot: fx.root.path,
      );
      expect(covering, isEmpty);
    });
  });

  group('zfa tdd refactor — scoped re-proof (T001 command)', () {
    Future<void> seedRegisteredMalformedSubject() async {
      // A registered behavior whose subject is malformed: `dart format`
      // (a pass-registry action) changes exactly that file, so the
      // pass-registry-changed set is {lib/b_001_subject.dart} and the
      // covering test is test/b_001_test.dart.
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: 'create entity User with email',
        subjectContent: 'int b_001_value() {  return  42 ;  }\n\n\n',
      );
    }

    test('a changed registered subject scopes the re-proof to its '
        'covering test — the full suite is not re-run', () async {
      await seedRegisteredMalformedSubject();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fakeZfa,
      ]);

      expect(out, contains('outcome=refactored'), reason: out);
      expect(exitCode, 0, reason: out);

      // The scoped re-proof names its scope.
      expect(out, contains('re-proof: scoped'), reason: out);

      // The pass-registry-changed files were persisted.
      final snapshot = await PassRegistryTracker.read(
        PassRegistryTracker.pathFor(featureDir: fx.featureDir),
      );
      expect(snapshot, isNotNull, reason: out);
      expect(
        snapshot!.unionChangedFiles(),
        contains('lib/b_001_subject.dart'),
        reason: out,
      );

      // The re-proof invocation carried the covering test path (scoped),
      // not the bare suite command: the spy logs one invocation per run
      // (preflight, then re-proof). The LAST invocation is the re-proof.
      final invocations = fx.spyLog('suite');
      expect(invocations, hasLength(2), reason: out);
      expect(invocations.last, contains('b_001_test.dart'), reason: out);
      // The cycle-log evidence records the scoped command.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('b_001_test.dart'));
      expect(cycleLog, contains('re-proof: scoped'));
    });

    test('a changed file that maps to no registered artifact falls back '
        'to the full-suite re-proof (safe failure, never narrowed)', () async {
      // The malformed file is UNREGISTERED (no artifact record maps to
      // it) and the registered subject stays clean: the covering set is
      // empty -> full suite.
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: 'create entity User with email',
      );
      await File(
        p.join(fx.root.path, 'lib', 'malformed.dart'),
      ).writeAsString('int unregistered() {  return  1 ;  }\n\n\n');

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fakeZfa,
      ]);

      expect(out, contains('outcome=refactored'), reason: out);
      expect(exitCode, 0, reason: out);
      // The fallback is NAMED, never silent.
      expect(out, contains('re-proof: full'), reason: out);

      final invocations = fx.spyLog('suite');
      expect(invocations, hasLength(2), reason: out);
      // The bare suite command (no test path args).
      expect(invocations.last.trim(), 'invoke', reason: out);
    });

    test(
      '--full-reproof forces the full suite even when the change set '
      'maps to covering tests (the feature-completion/nightly gate)',
      () async {
        await seedRegisteredMalformedSubject();

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'refactor',
          '--project',
          fx.root.path,
          '--zfa-bin',
          fakeZfa,
          '--full-reproof',
        ]);

        expect(out, contains('outcome=refactored'), reason: out);
        expect(exitCode, 0, reason: out);
        expect(out, contains('re-proof: full'), reason: out);
        final invocations = fx.spyLog('suite');
        expect(invocations, hasLength(2), reason: out);
        expect(invocations.last.trim(), 'invoke', reason: out);
      },
    );
  });
}
