// Bug #1573 — `zfa tdd doctor` prescribes a command form `zfa tdd
// migrate-paths` does not accept, and `migrate-paths` cannot reach the bug
// directories the doctor diagnoses.
//
// Issue state (the shipped `.specify/bugs/cycle-log-phantom-sections`
// fixture): the bug feature's registry records machine-absolute paths from
// a root that does not exist on this machine, so doctor correctly
// prescribes the path-form migration — but the prescription reads
// `zfa tdd migrate-paths cycle-log-phantom-sections`:
//
//   1. migrate-paths declares ONLY `--feature`; the prescription's
//      positional slug lands in `argResults.rest` and is silently
//      discarded, so the migration sweeps EVERY specs/ registry in the
//      project and rewrites an unrelated feature's records.
//   2. even the flag form (`--feature <slug>`) cannot reach the bug
//      directory: `_scanRegistries` resolves every feature under
//      `specs/`, so `.specify/bugs/<slug>/tdd/artifacts.json` is
//      unreachable and the prescribed command reports `migrated=0`.
//   3. the drift line re-renders the recorded path through the display
//      normalizer, so the operator cannot see the RAW recorded value the
//      drift is about.
//
// Contract under test:
// 1. doctor prescribes `zfa tdd migrate-paths --feature <ref>` with the
//    canonical feature reference (`.specify/bugs/<slug>` for a bug
//    feature), and the prescribed command actually heals the registry
//    (migrated > 0, doctor -> healthy).
// 2. an unrecognized positional argument is a LOUD usage error that names
//    the argument and points at `--feature` — never a silent
//    whole-project sweep (the bystander registry is untouched).
// 3. the no-flag sweep covers `.specify/bugs/<slug>/tdd/artifacts.json`
//    the same way it covers `specs/<feature>/tdd/artifacts.json`, and a
//    plain bug slug resolves through the bug extension's pin.
// 4. the path-form drift line prints the recorded value verbatim.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

void main() {
  late Directory tmpDir;
  late CliRunner runner;

  const slug = '1573-sample-bug';
  const bystander = '1573-bystander-feature';
  const bugRef = '.specify/bugs/$slug';

  /// Portable recorded form for the bug feature's pair.
  const relTestPath = 'test/tdd/$slug/a1_test.dart';
  const relSubjectPath = 'lib/tdd/$slug/a1_subject.dart';

  /// The bystander's portable forms (the sweep-hazard witness).
  const bystanderTestPath = 'test/tdd/$bystander/b1_test.dart';
  const bystanderSubjectPath = 'lib/tdd/$bystander/b1_subject.dart';

  /// Machine-absolute recorded form from a root that does not exist on
  /// this machine (the shipped bug dir's relocated-registry shape).
  late String foreignRoot;
  late String foreignTestPath;
  late String foreignSubjectPath;

  String registryJson(
    String feature, {
    required String testPath,
    required String subjectPath,
    String behaviorId = 'A1',
  }) => jsonEncode({
    'feature': feature,
    'records': [
      {
        'behavior_id': behaviorId,
        'feature': feature,
        'source_criterion': 'AC-1',
        'test_path': testPath,
        'subject_path': subjectPath,
        'runnable_test_name': '$testPath::$behaviorId::some behavior',
        'test_ownership': 'created',
        'subject_ownership': 'created',
        'created_at': '2026-09-10T22:29:38.000Z',
      },
    ],
  });

  List<String> doctorArgs(String featureRef) => [
    'tdd',
    'doctor',
    featureRef,
    '--project',
    tmpDir.path,
  ];

  List<String> migrateArgs([List<String> extra = const <String>[]]) => [
    'tdd',
    'migrate-paths',
    '--project',
    tmpDir.path,
    ...extra,
  ];

  File bugRegistryFile() => File(
    p.join(tmpDir.path, '.specify', 'bugs', slug, 'tdd', 'artifacts.json'),
  );

  File bystanderRegistryFile() =>
      File(p.join(tmpDir.path, 'specs', bystander, 'tdd', 'artifacts.json'));

  /// Seed `.specify/bugs/<slug>/tdd/artifacts.json` with one record.
  Future<void> seedBugFeature({
    required String testPath,
    required String subjectPath,
  }) async {
    final bugDir = Directory(p.join(tmpDir.path, '.specify', 'bugs', slug));
    await Directory(p.join(bugDir.path, 'tdd')).create(recursive: true);
    await File(p.join(bugDir.path, 'spec.md')).writeAsString('''
# Bug $slug

## Functional Requirements

- **AC-1**: some behavior
''');
    await bugRegistryFile().writeAsString(
      registryJson(slug, testPath: testPath, subjectPath: subjectPath),
    );
  }

  /// Create the bug feature's pair at the portable project-relative
  /// locations (plain content — nothing for the legacy-layout scan to
  /// classify).
  Future<void> seedBugArtifacts() async {
    for (final rel in [relTestPath, relSubjectPath]) {
      final file = File(p.join(tmpDir.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('// prior artifact\n');
    }
  }

  /// Seed a HEALTHY bystander specs/ feature whose record carries the
  /// resolving machine-absolute form of its own artifacts — a registry a
  /// whole-project sweep WOULD rewrite (the bug's collateral-damage
  /// shape) but a correct run must leave untouched.
  Future<File> seedBystanderDrift() async {
    final absTest = p.join(tmpDir.path, bystanderTestPath);
    final absSubject = p.join(tmpDir.path, bystanderSubjectPath);
    for (final abs in [absTest, absSubject]) {
      final file = File(abs);
      await file.parent.create(recursive: true);
      await file.writeAsString('// bystander artifact\n');
    }
    final file = bystanderRegistryFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      registryJson(
        bystander,
        testPath: absTest,
        subjectPath: absSubject,
        behaviorId: 'B1',
      ),
    );
    return file;
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

  Map<String, dynamic> bugRecords() {
    final raw = bugRegistryFile().readAsStringSync();
    return (jsonDecode(raw)['records'] as List).single as Map<String, dynamic>;
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1573_test_');
    foreignRoot = p.join(tmpDir.path, 'old-machine-root');
    foreignTestPath = p.join(foreignRoot, relTestPath);
    foreignSubjectPath = p.join(foreignRoot, relSubjectPath);
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Bug #1573 — the prescription is executable', () {
    test('doctor on a bug feature prescribes migrate-paths --feature '
        'with the canonical bug reference', () async {
      await seedBugArtifacts();
      await seedBugFeature(
        testPath: foreignTestPath,
        subjectPath: foreignSubjectPath,
      );

      final out = await runner.runCapturing(doctorArgs(bugRef));

      final v = verdict(out);
      expect(v['verdict'], 'drift');
      expect(v['prescription'], 'migrate');
      expect(
        fixLine(out),
        contains('zfa tdd migrate-paths --feature $bugRef'),
        reason:
            'the prescription must name the flag form AND the canonical '
            'reference that reaches the bug directory (out: $out)',
      );
    });

    test(
      'the prescribed command heals the bug registry (migrated > 0)',
      () async {
        await seedBugArtifacts();
        await seedBugFeature(
          testPath: foreignTestPath,
          subjectPath: foreignSubjectPath,
        );

        final out = await runner.runCapturing(
          migrateArgs(['--feature', bugRef]),
        );

        expect(
          out,
          contains('migrated=1'),
          reason:
              'the bug directory the doctor diagnosed must be reachable by '
              'the prescribed command (out: $out)',
        );
        expect(bugRecords()['test_path'], relTestPath);
        expect(bugRecords()['subject_path'], relSubjectPath);

        final healed = await runner.runCapturing(doctorArgs(bugRef));
        expect(
          verdict(healed)['verdict'],
          'healthy',
          reason: 'the prescribed migration closes the loop (out: $healed)',
        );
      },
    );

    test('a plain bug slug resolves through the bug extension pin', () async {
      await seedBugArtifacts();
      await seedBugFeature(
        testPath: foreignTestPath,
        subjectPath: foreignSubjectPath,
      );
      final pin = File(p.join(tmpDir.path, '.specify', 'feature.json'));
      await pin.parent.create(recursive: true);
      await pin.writeAsString(jsonEncode({'feature_directory': bugRef}));

      final out = await runner.runCapturing(migrateArgs(['--feature', slug]));

      expect(out, contains('migrated=1'), reason: out);
      expect(bugRecords()['test_path'], relTestPath);
    });
  });

  group('Bug #1573 — positional arguments are rejected loudly', () {
    test('an unrecognized positional is a usage error, never a '
        'whole-project sweep', () async {
      await seedBugArtifacts();
      await seedBugFeature(
        testPath: foreignTestPath,
        subjectPath: foreignSubjectPath,
      );
      // The collateral-damage witness: a form-drift registry the buggy
      // sweep rewrote while silently discarding the slug.
      final bystanderFile = await seedBystanderDrift();
      final bystanderBefore = bystanderFile.readAsStringSync();
      final bugBefore = bugRegistryFile().readAsStringSync();

      final out = await runner.runCapturing(migrateArgs([slug]));

      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.usage,
        reason:
            'a positional migrate-paths never learned must exit as a '
            'usage error, not success (out: $out)',
      );
      expect(out, contains('Unexpected positional argument'), reason: out);
      expect(
        out,
        contains('--feature'),
        reason: 'the refusal must point at the flag form (out: $out)',
      );
      expect(
        bystanderFile.readAsStringSync(),
        bystanderBefore,
        reason:
            'the discarded slug must NOT trigger a whole-project '
            'sweep that rewrites an unrelated feature (out: $out)',
      );
      expect(
        bugRegistryFile().readAsStringSync(),
        bugBefore,
        reason: 'nothing may be rewritten by a rejected invocation',
      );
    });
  });

  group('Bug #1573 — the sweep reaches the bug directories', () {
    test(
      'migrate-paths with no flag migrates a bug-directory registry',
      () async {
        await seedBugArtifacts();
        await seedBugFeature(
          testPath: foreignTestPath,
          subjectPath: foreignSubjectPath,
        );

        final out = await runner.runCapturing(migrateArgs());

        expect(
          out,
          contains('migrated=1'),
          reason:
              'the sweep covers every feature registry — the bug extension '
              'stores included (out: $out)',
        );
        expect(bugRecords()['test_path'], relTestPath);
        expect(bugRecords()['subject_path'], relSubjectPath);
      },
    );
  });

  group('Bug #1573 — the drift line names the raw recorded value', () {
    test('the path-form drift prints the recorded absolute string, not a '
        'normalized re-rendering', () async {
      // The mixed-form shape: the recorded machine-absolute paths RESOLVE
      // on this machine, so doctor reaches the path-form drift check —
      // whose whole point is the recorded FORM. The drift line must show
      // the recorded string itself.
      await seedBugArtifacts();
      final resolvingTest = p.join(tmpDir.path, relTestPath);
      final resolvingSubject = p.join(tmpDir.path, relSubjectPath);
      await seedBugFeature(
        testPath: resolvingTest,
        subjectPath: resolvingSubject,
      );

      final out = await runner.runCapturing(doctorArgs(bugRef));

      final v = verdict(out);
      expect(v['prescription'], 'migrate', reason: out);
      expect(
        (v['drifts'] as List).join(' '),
        contains(resolvingTest),
        reason:
            'the drift line must carry the RAW recorded value the '
            'migration will rewrite (out: $out)',
      );
    });
  });
}
