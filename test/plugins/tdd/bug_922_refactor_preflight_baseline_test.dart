@Tags(['slow'])
// Issue #922 — pre-existing red tests in the run's baseline are counted by
// the refactor preflight, blocking every behavior's done transition: the
// run ends `result=stopped ... green=13 done=0` even though every behavior
// IS green.
//
// Root cause: the spawned `zfa tdd refactor` preflight runs the full suite
// and refuses on ANY red (spec 048 FR-001). When the driving `zfa tdd run`
// cached a baseline with pre-existing failures in unrelated files (the
// issue #741 run-baseline.json), those failures are not NEW — the same U16
// discipline `make` already applies (pre-existing breakage doesn't fail the
// step) — yet refactor refuses, the driver skips every refactor, and the
// done gate never opens.
//
// Fix under test: the driver hands its cached baseline to refactor spawns
// (`--suite-baseline`, the same handoff issue #741 gave make), and refactor
// excludes the baseline's pre-existing failures from its preflight and
// re-proof verdicts — only NEW failures refuse. A flag-less standalone
// `zfa tdd refactor` keeps the absolute-green contract (spec 048 FR-001)
// unchanged, and a missing/corrupt cache falls back to it safely.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  // The build pass resolves its entrypoint through --zfa-bin (tier 1). In
  // a `dart test` context Platform.script is the test kernel — never a
  // usable zfa — so every invocation pins the fixture's fake system zfa
  // (the same discipline refactor_command_test applies; bug #689).
  late String fakeZfa;
  const feature = '090-tdd-fixture';

  /// Write a usable run-baseline cache with [failed] as the pre-existing
  /// failure identifiers (the RunBaselineCache contract).
  Future<void> writeBaseline(List<String> failed) async {
    final file = File(fx.runBaselinePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'command': 'dart test',
        'exitCode': 1,
        'failedTests': failed,
        'capturedAt': '2026-09-02T00:00:00.000Z',
        'parseable': true,
      }),
    );
  }

  /// Seed a failing test in an unrelated file (the "pre-existing red" the
  /// baseline records) and return the failing-test identifier the suite
  /// transcript prints for it.
  Future<String> seedPreExistingRed({
    String file = 'test/other/legacy_test.dart',
    String name = 'pre-existing legacy failure',
  }) async {
    final path = p.join(fx.root.path, file);
    await File(path).parent.create(recursive: true);
    await File(path).writeAsString('''
import 'package:test/test.dart';

void main() {
  test('$name', () {
    fail('pre-existing red — unrelated to the feature under refactoring');
  });
}
''');
    return '$file: $name';
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Build the CLI args for `zfa tdd refactor`, pinning the project root
  /// and the build-pass entrypoint so the in-process invocation never
  /// depends on Directory.current or Platform.script.
  List<String> refactorArgs({List<String> extra = const []}) => [
    'tdd',
    'refactor',
    '--project',
    fx.root.path,
    '--zfa-bin',
    fakeZfa,
    ...extra,
  ];

  group('refactor command — baseline excludes pre-existing red (#922)', () {
    test('preflight with ONLY baseline-recorded failures tolerates the red '
        'and refactors clean', () async {
      final legacyId = await seedPreExistingRed();
      await writeBaseline([legacyId]);
      await fx.seedAlreadyCleanLib();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=clean'), reason: out);
      expect(
        out,
        contains('every failure is pre-existing at baseline'),
        reason: out,
      );
      expect(exitCode, 0, reason: out);
      // Zero files modified: the tolerated red never justifies a mutation.
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('a NEW failure beyond the baseline still refuses (outcome=not-green) '
        'and names it — the guard is not destroyed by the exclusion', () async {
      final legacyId = await seedPreExistingRed();
      await writeBaseline([legacyId]);
      // A second, NOT-baselined failure — a real red refactor must refuse.
      await seedPreExistingRed(
        file: 'test/other/fresh_test.dart',
        name: 'fresh genuine failure',
      );
      await fx.seedAlreadyCleanLib();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=not-green'), reason: out);
      expect(out, contains('fresh genuine failure'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('re-proof with ONLY baseline-recorded failures is not a regression: '
        'applied passes certify (outcome=refactored, exit 0)', () async {
      final legacyId = await seedPreExistingRed();
      await writeBaseline([legacyId]);
      await fx.seedMalformedLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=refactored'), reason: out);
      expect(exitCode, 0, reason: out);
      // The evidence records the tolerated pre-existing red honestly.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('preflight: tolerated'));
      expect(log, contains('re-proof: tolerated'));
      expect(log, contains('issue #922'));
    });

    test('an UNPARSEABLE red transcript is never tolerated by the baseline — '
        'safe refusal (outcome=not-green)', () async {
      await writeBaseline(['test/other/legacy_test.dart: some failure']);
      // A suite template that produces an unusable transcript (no progress
      // markers) and exits 1 — could be a runner/compile failure; the
      // baseline must not wave it through.
      final brokenSuite = await fx.writeSpyScript(
        'broken-suite',
        output: 'boom — no parseable transcript here',
        exit: '1',
      );
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: brokenSuite,
      );
      await fx.seedAlreadyCleanLib();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=not-green'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('a missing/corrupt baseline cache falls back to the absolute-green '
        'contract (safe failure, never a silent pass)', () async {
      final file = File(fx.runBaselinePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('{not valid json');
      await fx.seedRedSuite();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=not-green'), reason: out);
      expect(out, contains('unreadable'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });

    test('an UNPARSEABLE re-proof transcript is a regression, never '
        'baseline-tolerated (mutation M2: the parseable guard is load '
        'bearing)', () async {
      // The preflight sees a parseable red that the baseline fully
      // accounts for (tolerated), but the RE-PROOF transcript is garbage.
      // A red the parser cannot name may be a runner/compile failure the
      // passes just caused — the baseline must not wave it through.
      await writeBaseline(['test/other/legacy_test.dart: legacy failure']);
      final phaseLog = p.join(fx.spyDir, 'two-phase.log');
      final twoPhase = p.join(fx.spyDir, 'two-phase-suite');
      await Directory(fx.spyDir).create(recursive: true);
      const spyScript = r'''
#!/bin/sh
echo "invoke" >> "__PHASELOG__"
N=$(grep -c invoke "__PHASELOG__")
if [ "$N" -le 1 ]; then
  cat <<'SPY_EOF'
00:00 +0 -1: test/other/legacy_test.dart: legacy failure [E]
00:00 +0 -1: Some tests failed.
SPY_EOF
  exit 1
else
  echo "boom — re-proof transcript is unparseable"
  exit 1
fi
''';
      await File(
        twoPhase,
      ).writeAsString(spyScript.replaceAll('__PHASELOG__', phaseLog));
      Process.runSync('chmod', ['+x', twoPhase]);
      await fx.rewriteProfile(
        singleTemplate: TddFixture.defaultSingleTemplate,
        suiteTemplate: twoPhase,
      );
      await fx.seedMalformedLib();
      final testTreeBefore = fx.checksumTestTree();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        refactorArgs(extra: ['--suite-baseline', fx.runBaselinePath]),
      );

      expect(out, contains('outcome=regression'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      // test/ stays byte-identical (FR-004) even though the format pass
      // may have normalized lib/ before the unparseable re-proof fired.
      expect(fx.checksumTestTree(), equals(testTreeBefore));
    });

    test('standalone refactor (no flag) on a red suite still refuses — '
        'the spec 048 FR-001 absolute-green contract is unchanged', () async {
      await fx.seedRedSuite();
      final checksumsBefore = fx.checksumTestAndLib();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(refactorArgs());

      expect(out, contains('outcome=not-green'), reason: out);
      expect(exitCode, isNot(0), reason: out);
      expect(fx.checksumTestAndLib(), equals(checksumsBefore));
    });
  });

  group('run driver — refactor spawns carry the run baseline (#922)', () {
    test('the driver passes --suite-baseline to refactor steps the same way '
        'issue #741 passed it to make steps', () async {
      final suiteSpy = await fx.writeSpyScript(
        'suite',
        output: TddFixture.oneRedSuiteTranscript,
        exit: '1',
      );
      final singleSpy = await fx.writeSpyScript(
        'single',
        output: '00:00 +1: unused: unused\n00:00 +1: All tests passed!',
      );
      await fx.rewriteProfile(
        singleTemplate: '$singleSpy {file} {name}',
        suiteTemplate: suiteSpy,
      );
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // Seeded GREEN with complete evidence: only its refactor is left —
      // the exact issue #922 run shape (green=N, done=0).
      await fx.registerBehavior(
        id: 'B-001',
        description: 'first behavior',
        writeTestFile: false,
      );
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'green'});

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(exitCode, 0, reason: out);
      // The baseline was cached from the suite spy (1 pre-existing failure).
      expect(File(fx.runBaselinePath).existsSync(), isTrue, reason: out);
      final refactorArgv = fx
          .stepArgvLog()
          .where((line) => line.contains(' refactor '))
          .toList();
      expect(refactorArgv, hasLength(1), reason: out);
      expect(refactorArgv.single, contains('--suite-baseline'), reason: out);
      expect(refactorArgv.single, contains(fx.runBaselinePath), reason: out);
    });
  });

  group('run driver end-to-end — pre-existing red does not stop the done '
      'gate (#922 signature)', () {
    test('a green behavior behind a baseline-red suite reaches done and the '
        'run completes', () async {
      // The REAL loop: real `dart test` suites in the fixture, the REAL
      // refactor command reached through an exec forwarder (transport
      // only — the same discipline as sc_017). The suite is red from a
      // pre-existing failure in an unrelated file; the behavior itself is
      // certified green. Pre-fix this run ends with the issue #922
      // signature (`result=stopped ... green=1 done=0
      // stopped_at=B-001:refactor`); post-fix the spawned refactor
      // excludes the baseline red and the behavior reaches done.
      final repoRoot = _findZuraffaRoot();
      final forwarder = await _writeRealZfaForwarder(fx, repoRoot);

      // The fixture must be genuinely buildable: the refactor's build
      // pass resolves the REAL zfa (Platform.script tier) and `zfa build`
      // needs build_runner + codegen deps to exit 0 (the sc_017
      // provisioning).
      await File(p.join(fx.root.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy: any
  zorphy_annotation: any
  json_annotation: any
dev_dependencies:
  build_runner: any
  json_serializable: any
  test: ^1.25.0
''');
      final pubGet = await Process.run(Platform.resolvedExecutable, [
        'pub',
        'get',
      ], workingDirectory: fx.root.path);
      expect(
        pubGet.exitCode,
        0,
        reason: 'fixture pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
      );

      final legacyId = await seedPreExistingRed();
      await writeBaseline([legacyId]);
      await fx.seedAlreadyCleanLib();
      // The driver caches its OWN baseline (phase 6b, issue #741) — the
      // hand-written one above only satisfies the helper contract; the run
      // overwrites it with the live suite snapshot.
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.registerBehavior(
        id: 'B-001',
        description: 'first behavior',
        writeTestFile: false,
      );
      await fx.seedRedEvidence('B-001');
      await fx.seedGreenEvidence('B-001');
      await fx.seedRunState(states: {'B-001': 'green'});

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        forwarder,
      ]);

      expect(
        out,
        contains(
          'run: feature=$feature result=complete pending=0 red=0 green=0 '
          'done=1',
        ),
        reason: out,
      );
      expect(exitCode, 0, reason: out);
      final state =
          jsonDecode(await File(fx.runStatePath).readAsString())
              as Map<String, dynamic>;
      expect(state['behavior_states'] as Map<String, dynamic>, {
        'B-001': 'done',
      });
    }, timeout: const Timeout(Duration(minutes: 6)));
  });
}

/// Absolute path to the zuraffa repo root (the real zfa CLI source) —
/// the sc_017 walk-up pattern.
String _findZuraffaRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}

/// Write an exec forwarder as the driver's `--zfa-bin`: `tdd ...` argv is
/// forwarded to the REAL bin/zfa.dart (transport only); anything else (the
/// refactor build pass invoking `<zfa-bin> build`) exits 0 without
/// semantics — the pass registry behavior is covered by its own suites.
Future<String> _writeRealZfaForwarder(TddFixture fx, String repoRoot) async {
  final realBin = File(p.join(repoRoot, 'bin', 'zfa.dart'));
  if (!realBin.existsSync()) {
    throw StateError('real zfa entrypoint not found at ${realBin.path}');
  }
  final binDir = Directory(p.join(fx.root.path, '.real-zfa'));
  await binDir.create(recursive: true);
  final scriptPath = p.join(binDir.path, 'zfa');
  final argvLog = p.join(binDir.path, 'argv.log');
  const script = r'''
#!/bin/sh
echo "$@" >> "__ARGVLOG__"
if [ "$1" = "tdd" ]; then
  exec "__DART__" "__REALBIN__" "$@"
fi
exit 0
''';
  await File(scriptPath).writeAsString(
    script
        .replaceAll('__ARGVLOG__', argvLog)
        .replaceAll('__DART__', Platform.resolvedExecutable)
        .replaceAll('__REALBIN__', realBin.path),
  );
  Process.runSync('chmod', ['+x', scriptPath]);
  return scriptPath;
}
