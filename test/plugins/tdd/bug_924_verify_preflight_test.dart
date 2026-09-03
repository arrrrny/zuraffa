// Bug #924 — `zfa tdd verify` hangs on a full-suite baseline with many
// pre-existing failures; the missing-mutation-config NOT_ASSESSED verdict
// is never reached because the preflight runs first.
//
// Test tiers: the unit groups run in the FAST tier (no subprocesses); the
// CLI group carries `slow` + `integration` (it pub-gets a temp fixture).
//
// RED evidence (pre-fix master):
//   * config-first — with the mutation config unresolvable, the auditor
//     still runs the preflight (the suite) before discovering the config
//     error; the report reason is `mutation audit failed: …`, not a
//     config error, and the preflight was invoked.
//   * per-behavior preflight — the default preflight runs ONE combined
//     `dart test` over the whole scope (the full-suite baseline that
//     hangs at corpus scale), there is no per-behavior fail-fast, and no
//     `preflight_scope_ran` diagnostic in verification.md.
//
// Contract pinned here (remediation, minimal):
//   1. `gate: not_assessed` (missing mutation config) is returned
//      IMMEDIATELY — before any test runs. `--timeout` keeps bounding the
//      preflight phase (bug #742 contract) and the command exits non-zero
//      on timeout (usage class 64, NOT_ASSESSED — never a bare hang).
//   2. The preflight uses the per-behavior test (the TDD profile's
//      single/file template shape) when the feature has its own test
//      files: each registered test file runs individually, failing fast
//      on the first red; no full-suite fallback. The files actually run
//      are reported as `preflight_scope_ran` diagnostics.
//   3. When the feature has no own test files the preflight runs nothing
//      (no full-suite fallback) — unchanged green no-op.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/mutation_outcome.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('unit — config-first: missing mutation config → NOT_ASSESSED '
      'immediately, the preflight never runs (bug #924)', () {
    late Directory tmpDir;
    late String featureDir;
    var preflightInvoked = false;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug924_config_first_');
      featureDir = p.join(tmpDir.path, 'specs', '090-bug-924');
      preflightInvoked = false;
      // One registered scope pair whose subject exists on disk (a real
      // scope — the empty-scope NOT_ASSESSED path is FR-012, not #924).
      File(p.join(tmpDir.path, 'lib', 'tdd', 'b_001_subject.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('int add(int a, int b) => a + b;\n');
      File(p.join(featureDir, 'tdd', 'artifacts.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'feature': '090-bug-924',
            'records': [
              {
                'behavior_id': 'B-001',
                'feature': '090-bug-924',
                'source_criterion': 'FR-001',
                'test_path': 'test/tdd/b_001_test.dart',
                'subject_path': 'lib/tdd/b_001_subject.dart',
                'runnable_test_name': 'x::B-001::y',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-03T00:00:00.000Z',
              },
            ],
          }),
        );
      // The mutation config is UNRESOLVABLE: `.dart_tool` exists as a
      // plain FILE, so the auditor cannot create
      // `.dart_tool/zfa/tdd-verify-mutation.xml` (the per-preset config
      // lookup failure the issue reports — `mutation-test.xml not found`
      // in forklift).
      File(p.join(tmpDir.path, '.dart_tool')).writeAsStringSync('not a dir');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test(
      'config error → NOT_ASSESSED before any test process is spawned',
      () async {
        final auditor = MutationAuditor(
          featureDir: featureDir,
          workingDirectory: tmpDir.path,
          runPreflight: (scopePaths) async {
            preflightInvoked = true;
            return PreflightResult.green(exitCode: 0, output: 'preflight ran');
          },
          // Default mutation path (no runMutation override): the config
          // resolution is what must fail FIRST, before the preflight.
        );

        final report = await auditor.run();

        expect(report.gate, MutationGateDecision.notAssessed);
        expect(
          report.notAssessedReason,
          contains('mutation config'),
          reason:
              'the verdict must name the missing/unresolvable mutation '
              'config, not a generic audit failure',
        );
        expect(report.mutationWasRun, isFalse);
        expect(
          preflightInvoked,
          isFalse,
          reason:
              'bug #924: the missing-mutation-config NOT_ASSESSED verdict '
              'must be returned immediately — the full-suite preflight '
              'must never run first (the hang the issue reports)',
        );
      },
    );
  });

  group('unit — per-behavior preflight: fail-fast over the feature\'s own '
      'test files (bug #924)', () {
    late Directory tmpDir;
    late String featureDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug924_per_behavior_');
      featureDir = p.join(tmpDir.path, 'specs', '090-bug-924');
      File(p.join(tmpDir.path, 'lib', 'tdd', 'b_001_subject.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('int add(int a, int b) => a + b;\n');
      File(p.join(featureDir, 'tdd', 'artifacts.json'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({
            'feature': '090-bug-924',
            'records': [
              for (final id in ['B-001', 'B-002', 'B-003'])
                {
                  'behavior_id': id,
                  'feature': '090-bug-924',
                  'source_criterion': 'FR-001',
                  'test_path':
                      'test/tdd/b_00${id.substring(id.length - 1)}_test.dart',
                  'subject_path': 'lib/tdd/b_001_subject.dart',
                  'runnable_test_name': 'x::$id::y',
                  'test_ownership': 'created',
                  'subject_ownership': 'created',
                  'created_at': '2026-09-03T00:00:00.000Z',
                },
            ],
          }),
        );
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    MutationAuditor auditor({
      required Future<PreflightResult> Function(String testPath)
      runPreflightBehavior,
    }) => MutationAuditor(
      featureDir: featureDir,
      workingDirectory: tmpDir.path,
      runPreflightBehavior: runPreflightBehavior,
      runMutation: () async => throw UnimplementedError('should not run'),
    );

    test(
      'runs each behavior test individually and stops at the first red',
      () async {
        final ran = <String>[];
        final report = await auditor(
          runPreflightBehavior: (testPath) {
            ran.add(testPath);
            if (testPath.endsWith('b_002_test.dart')) {
              return Future.value(
                PreflightResult.red(exitCode: 1, output: 'B-002 is red'),
              );
            }
            return Future.value(
              PreflightResult.green(exitCode: 0, output: '$testPath green'),
            );
          },
        ).run();

        expect(report.gate, MutationGateDecision.preflightRed);
        expect(
          ran,
          hasLength(2),
          reason: 'fail-fast: B-003 must never run after B-002 is red',
        );
        expect(
          report.preflightScopeRan,
          equals(ran),
          reason:
              'the files actually executed must be surfaced as '
              'preflight_scope_ran diagnostics (bug #924)',
        );
        expect(report.preflightOutput, contains('B-002 is red'));
      },
    );

    test('all green per-behavior files → the preflight is green and every '
        'file ran', () async {
      final report = await auditor(
        runPreflightBehavior: (testPath) => Future.value(
          PreflightResult.green(exitCode: 0, output: '$testPath green'),
        ),
      ).run();

      // The mutation phase is overridden to explode, so a green
      // preflight reaches it and surfaces the override error as
      // NOT_ASSESSED — the point here is the preflight verdict.
      expect(report.notAssessedReason, isNot(contains('preflight')));
      expect(report.preflightScopeRan, hasLength(3));
    });

    test('the whole preflight phase stays bounded by the --timeout budget '
        '(bug #924 point 1, service level)', () async {
      final report = await MutationAuditor(
        featureDir: featureDir,
        workingDirectory: tmpDir.path,
        preflightTimeout: const Duration(milliseconds: 150),
        runPreflightBehavior: (testPath) => Future.delayed(
          const Duration(milliseconds: 120),
          () => PreflightResult.green(exitCode: 0, output: 'slow green'),
        ),
      ).run();

      expect(report.gate, MutationGateDecision.notAssessed);
      expect(report.notAssessedReason, contains('preflight timed out'));
    });

    test('no own test files → nothing runs, no full-suite fallback', () async {
      final emptyFeatureDir = p.join(tmpDir.path, 'specs', '090-empty');
      Directory(p.join(emptyFeatureDir, 'tdd')).createSync(recursive: true);
      File(
        p.join(emptyFeatureDir, 'tdd', 'artifacts.json'),
      ).writeAsStringSync(jsonEncode({'feature': '090-empty', 'records': []}));
      var invoked = false;
      final report = await MutationAuditor(
        featureDir: emptyFeatureDir,
        workingDirectory: tmpDir.path,
        runPreflightBehavior: (testPath) async {
          invoked = true;
          return PreflightResult.green(exitCode: 0, output: '');
        },
        runMutation: () async => throw UnimplementedError('should not run'),
      ).run();

      // Empty scope → NOT_ASSESSED (FR-012) without any preflight work.
      expect(report.gate, MutationGateDecision.notAssessed);
      expect(invoked, isFalse);
    });
  });

  group('unit — preflightFileResultFromProcess: per-behavior file verdict '
      '(bug #924, mutation finding M-1)', () {
    test('exit 0 → green', () {
      final r = preflightFileResultFromProcess(
        exitCode: 0,
        output: 'All tests passed!',
      );
      expect(r.isGreen, isTrue);
      expect(r.exitCode, 0);
      expect(r.output, 'All tests passed!');
    });

    test('non-zero exit → red, exit code preserved', () {
      for (final code in [1, 2, 254, 255]) {
        final r = preflightFileResultFromProcess(
          exitCode: code,
          output: 'failed',
        );
        expect(r.isGreen, isFalse, reason: 'exit $code must classify red');
        expect(r.exitCode, code, reason: 'exit $code must be preserved');
      }
    });
  });

  group('CLI — zfa tdd verify on a pre-existing-red fixture (bug #924)', () {
    late TddFixture fx;
    var exitCodeAtEntry = 0;

    Future<String> runCli(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        ...args,
        '--project',
        fx.root.path,
        '--timeout',
        '0.2',
      ]);
    }

    /// A pub-resolved fixture (the state `zfa tdd init` leaves behind)
    /// with TWO registered behaviors: B-001 red, B-002 green.
    Future<void> seedRedThenGreenFixture({bool hangingRed = false}) async {
      final redBody = hangingRed
          ? "while (true) {} // hangs — must never be reached pre-fix\n"
          : 'expect(1, equals(2));\n';
      File(p.join(fx.root.path, 'test', 'b_001_test.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('B-001 — red scope test', () {
    $redBody
  });
}
''');
      File(p.join(fx.root.path, 'test', 'b_002_test.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('B-002 — green scope test', () {
    expect(1, equals(1));
  });
}
''');
      File(p.join(fx.root.path, 'lib', 'b_001_subject.dart'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('int add(int a, int b) => a + b;\n');
      await fx.registerBehavior(
        id: 'B-001',
        description: 'red scope test',
        sourceCriterion: 'FR-001',
        writeTestFile: false,
      );
      await fx.registerBehavior(
        id: 'B-002',
        description: 'green scope test',
        sourceCriterion: 'FR-002',
        writeTestFile: false,
      );
      File(p.join(fx.root.path, 'pubspec.yaml')).writeAsStringSync('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
  mutation_test: ^1.8.0
''');
      final pubGet = await Process.run('dart', [
        'pub',
        'get',
      ], workingDirectory: fx.root.path);
      expect(
        pubGet.exitCode,
        0,
        reason: 'fixture pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
      );
    }

    setUp(() async {
      exitCodeAtEntry = exitCode;
      fx = await TddFixture.create(featureName: '090-bug-924');
    });

    tearDown(() {
      fx.dispose();
      exitCode = exitCodeAtEntry;
    });

    test('V1: missing mutation config → NOT_ASSESSED immediately — the '
        'suite (even a hanging one) never runs (bug #924)', () async {
      await seedRedThenGreenFixture(hangingRed: true);
      // The mutation config is unresolvable: `.dart_tool` replaced by a
      // plain file AFTER pub get (the `mutation-test.xml not found`
      // per-preset lookup failure the issue reports).
      final dartToolDir = Directory(p.join(fx.root.path, '.dart_tool'));
      dartToolDir.deleteSync(recursive: true);
      File(p.join(fx.root.path, '.dart_tool')).writeAsStringSync('not a dir');

      final out = await runCli(['verify', '--feature', '090-bug-924']);

      expect(
        out,
        contains('mutation: gate=not_assessed'),
        reason: 'the config verdict must be reached immediately',
      );
      expect(out, contains('mutation_was_run=false'));
      // 64 usage class: in-process the runner's _exit(64) is a no-op
      // (exitOnCompletion: false), so pin the class by output — the same
      // convention bug_837 C3 uses. The real process exits 64 via exit().
      expect(out, contains('❌ mutation audit gate: not_assessed'));
      expect(
        exitCode,
        isNot(1),
        reason:
            'a config refusal stays in the 64 usage class, not the '
            'quality-failure class',
      );
      final md = File(
        p.join(fx.featureDir, 'tdd', 'verification.md'),
      ).readAsStringSync();
      expect(md, contains('gate: `not_assessed`'));
      expect(
        md,
        contains('mutation config'),
        reason:
            'the reason must name the mutation config — NOT a preflight '
            'timeout (which would mean the suite ran first, the hang '
            'bug #924 reports)',
      );
      expect(md, isNot(contains('preflight timed out')));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('V2: per-behavior preflight fail-fast — the red file stops the '
        'run and the diagnostics name exactly what ran (bug #924)', () async {
      await seedRedThenGreenFixture();

      final out = await runCli(['verify', '--feature', '090-bug-924']);

      expect(out, contains('mutation: gate=preflight_red'));
      expect(out, contains('mutation_was_run=false'));
      expect(out, contains('❌ mutation audit gate: preflight_red'));
      expect(
        exitCode,
        isNot(1),
        reason:
            'preflight refusal stays in the 64 usage class (the real '
            'process exits 64 via exit(); _exit is a no-op in-process)',
      );
      final md = File(
        p.join(fx.featureDir, 'tdd', 'verification.md'),
      ).readAsStringSync();
      expect(md, contains('gate: `preflight_red`'));
      expect(
        md,
        contains('preflight_scope_ran'),
        reason:
            'the per-behavior preflight must surface the files it '
            'actually ran (bug #924 diagnostics)',
      );
      expect(md, contains('b_001_test.dart'));
      expect(
        md,
        isNot(contains('b_002_test.dart')),
        reason:
            'fail-fast: the green B-002 file must not run after B-001 '
            'is red',
      );
    }, timeout: const Timeout(Duration(minutes: 3)));
  }, tags: ['slow', 'integration']);
}
