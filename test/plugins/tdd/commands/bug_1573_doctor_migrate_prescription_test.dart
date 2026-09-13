// No `slow` tag: this suite is a fast in-process fixture test (CliRunner
// spawns no subprocesses) so the default CI tier runs the #1573 guard on
// every build.
// Bug #1573 — doctor prescribes a nonexistent command form, and
// migrate-paths cannot reach the registry the prescription names.
//
// Issue state: `zfa tdd doctor` detects machine-absolute recorded paths and
// prescribes `zfa tdd migrate-paths <feature>` — the POSITIONAL form. The
// command declares no positional argument: the slug is silently discarded
// (`argResults.rest` is never read) and the no-flag sweep migrates EVERY
// specs/ registry instead of the named one. Even the correct `--feature`
// form cannot reach a bug feature: `_scanRegistries` resolves a plain name
// to `specs/<name>` only, while a bug feature's registry lives at
// `.specify/bugs/<slug>/tdd/artifacts.json`. And the doctor's path-form
// drift line prints the recorded value NORMALIZED (a relative display form)
// while claiming the value is machine-absolute.
//
// Live repro on this repo's own fixture (pre-fix HEAD):
//
//   zfa tdd doctor .specify/bugs/cycle-log-phantom-sections
//     --> fix: zfa tdd migrate-paths cycle-log-phantom-sections
//   zfa tdd migrate-paths cycle-log-phantom-sections --dry-run
//     migrate-paths: migrated=92 ... feature=all   (slug discarded!)
//   zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run
//     migrate-paths: migrated=0 ...                (bug dir unreachable)
//
// Contract under test:
// 1. Doctor emits `fix: 'zfa tdd migrate-paths --feature $feature'` — and
//    the closing test EXECUTES the prescribed command and asserts
//    migrated > 0 (the prescription is verified by execution, not string
//    shape), after which doctor reports healthy.
// 2. `migrate-paths` covers `.specify/bugs/<slug>/tdd/artifacts.json` —
//    through the plain-slug flag form (pin file NOT required) and through
//    the whole-project sweep (bug registries join the specs/ sweep).
// 3. Unrecognized positional arguments are rejected loudly: usage exit 2,
//    the message names the --feature flag form, nothing migrates.
// 4. The path-form drift line prints the RAW recorded value, not the
//    normalized relative display form.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

void main() {
  late Directory tmpDir;

  const slug = '1573-phantom-fence';
  const specsFeature = 'plain-feature';

  late String absTestPath;
  late String absSubjectPath;

  const relTestPath = 'test/tdd/$slug/a1_test.dart';
  const relSubjectPath = 'lib/tdd/$slug/a1_subject.dart';

  /// The machine-absolute registry record (the issue's shape: gen's
  /// pre-#1397 default form, committed from another checkout).
  String registryJson({
    required String feature,
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
        'runnable_test_name': '$testPath::$behaviorId::the fence holds',
        'test_ownership': 'created',
        'subject_ownership': 'created',
        'created_at': '2026-09-10T22:29:38.012682Z',
      },
    ],
  });

  /// Seed the bug feature directory the way the bug extension lays it out
  /// (`.specify/bugs/<slug>/`) and register the pair under machine-absolute
  /// paths that DO resolve on this machine (the doctor path-form check 2e
  /// shape, distinct from the relocated-registry check 2c).
  Future<void> seedBugFeature({bool withPin = false}) async {
    final bugDir = Directory(
      p.join(tmpDir.path, '.specify', 'bugs', slug, 'tdd'),
    );
    await bugDir.create(recursive: true);
    await File(p.join(bugDir.parent.path, 'spec.md')).writeAsString(
      '# Spec for $slug\n\n## Acceptance Criteria\n\n- **AC-1**: the fence holds\n',
    );
    await File(p.join(bugDir.path, 'test-list.md')).writeAsString(
      '# Test List\n\n| id | behavior | traces | kind | state | target |\n|----|----------|--------|------|-------|--------|\n| A1 | the fence holds | AC-1 | unit | PENDING | subject |\n',
    );
    await File(p.join(bugDir.path, 'artifacts.json')).writeAsString(
      registryJson(
        feature: slug,
        testPath: absTestPath,
        subjectPath: absSubjectPath,
      ),
    );
    if (withPin) {
      await File(
        p.join(tmpDir.path, '.specify', 'feature.json'),
      ).writeAsString(jsonEncode({'feature_directory': '.specify/bugs/$slug'}));
    }
  }

  /// Create the pair on disk at the namespaced project-relative locations.
  Future<void> seedArtifacts() async {
    for (final rel in [relTestPath, relSubjectPath]) {
      final file = File(p.join(tmpDir.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('// prior artifact — no imports\n');
    }
  }

  /// Seed a plain specs/ feature carrying the same machine-absolute drift
  /// (the sweep must repair BOTH kinds of registry).
  Future<void> seedSpecsFeature() async {
    final tddDir = Directory(p.join(tmpDir.path, 'specs', specsFeature, 'tdd'));
    await tddDir.create(recursive: true);
    for (final rel in [
      'test/tdd/$specsFeature/b1_test.dart',
      'lib/tdd/$specsFeature/b1_subject.dart',
    ]) {
      final file = File(p.join(tmpDir.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsString('// prior artifact — no imports\n');
    }
    await File(p.join(tddDir.path, 'artifacts.json')).writeAsString(
      registryJson(
        feature: specsFeature,
        testPath: p.join(tmpDir.path, 'test/tdd/$specsFeature/b1_test.dart'),
        subjectPath: p.join(
          tmpDir.path,
          'lib/tdd/$specsFeature/b1_subject.dart',
        ),
        behaviorId: 'B1',
      ),
    );
  }

  Future<void> writeBugRegistry({required bool machineAbsolute}) async {
    await File(
      p.join(tmpDir.path, '.specify', 'bugs', slug, 'tdd', 'artifacts.json'),
    ).writeAsString(
      registryJson(
        feature: slug,
        testPath: machineAbsolute ? absTestPath : 'test/tdd/$slug/a1_test.dart',
        subjectPath: machineAbsolute
            ? absSubjectPath
            : 'lib/tdd/$slug/a1_subject.dart',
      ),
    );
  }

  String storedBugTestPath() {
    final raw = File(
      p.join(tmpDir.path, '.specify', 'bugs', slug, 'tdd', 'artifacts.json'),
    ).readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return ((decoded['records'] as List).single
            as Map<String, dynamic>)['test_path']
        as String;
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

  List<String> doctorArgs() => [
    'tdd',
    'doctor',
    '.specify/bugs/$slug',
    '--project',
    tmpDir.path,
  ];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1573_test_');
    absTestPath = p.join(tmpDir.path, relTestPath);
    absSubjectPath = p.join(tmpDir.path, relSubjectPath);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  group('Bug #1573 — the prescription closes the loop', () {
    test('the prescribed migrate-paths command executes and repairs the '
        'diagnosed bug registry', () async {
      await seedBugFeature();
      await seedArtifacts();
      final runner = CliRunner(exitOnCompletion: false);

      // Doctor diagnoses the machine-absolute registry and prescribes
      // the migration — in the form the command actually parses.
      final out = await runner.runCapturing(doctorArgs());
      final v = verdict(out);
      expect(v['verdict'], 'drift');
      expect(v['prescription'], 'migrate');
      expect(
        v['fix'],
        'zfa tdd migrate-paths --feature $slug',
        reason:
            'the prescription must be the flag form — the positional '
            'form is silently discarded by migrate-paths (issue #1573)',
      );
      expect(fixLine(out), contains('zfa tdd migrate-paths --feature $slug'));

      // SC-4: EXECUTE the prescribed command (the tokenized `--> fix:`
      // payload; `--project` is test-harness plumbing, the same way the
      // #1397 suite passes the fixture root) and require the migration
      // to actually move the registry.
      final command = fixLine(out).split(' — ').first.trim();
      final tokens = command.split(RegExp(r'\s+'));
      expect(tokens.take(3), ['zfa', 'tdd', 'migrate-paths']);
      expect(tokens[3], '--feature');
      expect(tokens[4], slug);
      final migrateOut = await runner.runCapturing([
        ...tokens.sublist(1),
        '--project',
        tmpDir.path,
      ]);
      final match = RegExp(r'migrated=(\d+)').firstMatch(migrateOut);
      expect(match, isNotNull, reason: migrateOut);
      expect(
        int.parse(match!.group(1)!),
        greaterThan(0),
        reason:
            'the prescribed command must migrate the diagnosed '
            'registry — migrated=0 means the bug directory was never '
            'examined (issue #1573)',
      );
      expect(
        storedBugTestPath(),
        relTestPath,
        reason:
            'the migration rewrites the recorded form to the '
            'portable project-relative POSIX form',
      );

      // The loop closes: the healed registry reads healthy.
      final healed = await runner.runCapturing(doctorArgs());
      expect(verdict(healed)['verdict'], 'healthy', reason: healed);
    });

    test('a positional feature argument is rejected loudly instead of '
        'silently sweeping every registry', () async {
      await seedBugFeature();
      await seedArtifacts();
      final runner = CliRunner(exitOnCompletion: false);

      // The positional form the doctor USED to prescribe: today the
      // slug is silently discarded and the no-flag sweep runs.
      final out = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        slug,
        '--project',
        tmpDir.path,
      ]);

      expect(
        exitCode,
        ExitProtocol.usage,
        reason:
            'an unrecognized positional argument is a usage error — '
            'output was: $out',
      );
      expect(
        out,
        contains('--feature'),
        reason: 'the refusal must name the flag form the command parses',
      );
      expect(
        storedBugTestPath(),
        absTestPath,
        reason: 'nothing may migrate through a rejected invocation',
      );
    });

    test('the flag form reaches the bug registry and the whole-project '
        'sweep covers bug directories', () async {
      await seedBugFeature();
      await seedArtifacts();
      final runner = CliRunner(exitOnCompletion: false);

      // Plain-slug flag form, NO pin file: the conventional
      // .specify/bugs/<slug> probe must find the registry.
      final flagOut = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        '--feature',
        slug,
        '--project',
        tmpDir.path,
      ]);
      expect(flagOut, contains('migrated=1'), reason: flagOut);
      expect(storedBugTestPath(), relTestPath, reason: flagOut);

      // Re-dirty the bug registry and add a plain specs/ feature: the
      // no-flag sweep repairs BOTH — specs/ first, bug dirs included.
      await writeBugRegistry(machineAbsolute: true);
      await seedSpecsFeature();
      final sweepOut = await runner.runCapturing([
        'tdd',
        'migrate-paths',
        '--project',
        tmpDir.path,
      ]);
      expect(sweepOut, contains('migrated=2'), reason: sweepOut);
      expect(sweepOut, contains('in $specsFeature'), reason: sweepOut);
      expect(
        sweepOut,
        contains('in $slug'),
        reason:
            'the sweep must examine .specify/bugs/<slug>/tdd/ '
            'registries, not only specs/ (issue #1573)',
      );
      expect(storedBugTestPath(), relTestPath, reason: sweepOut);
    });

    test('the path-form drift line prints the raw recorded value', () async {
      await seedBugFeature();
      await seedArtifacts();
      final runner = CliRunner(exitOnCompletion: false);

      final out = await runner.runCapturing(doctorArgs());

      final driftLines = out
          .split('\n')
          .where((l) => l.trim().startsWith('drift:'))
          .join('\n');
      expect(
        driftLines,
        contains(absTestPath),
        reason:
            'the drift line claims the recorded path is '
            'machine-absolute — it must print the RAW recorded string, '
            'not the normalized relative display form',
      );
      expect(
        driftLines,
        isNot(contains('machine-absolute ($relTestPath)')),
        reason:
            'the normalized relative form is the one value the drift '
            'line must NOT show (the recorded form IS the finding)',
      );
    });
  });
}
