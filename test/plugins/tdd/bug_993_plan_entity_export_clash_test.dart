@Tags(['regression'])
library;

// Regression tests for issue #993:
// https://github.com/arrrrny/zuraffa/issues/993
//
// `zfa tdd plan` accepted Key Entity names that collide with the zuraffa
// framework export surface (e.g. `AgentState`, exported by
// `package:zuraffa/zuraffa.dart` via `src/agent/runtime/state_storage.dart`)
// and wrote the test list anyway. `zfa tdd run` then stopped at phase-0:
// the #942 preflight inside `zfa entity create` refuses the colliding
// name, so the driver recorded `phase-0 entity failed` and the run halted
// BEFORE any behavior was driven (repro: `zfa tdd run
// 013-agent-modes-killswitch --timeout 5` against a spec declaring
// `**AgentState**`). The detection existed — but only at run time.
//
// The fix: plan runs the SAME export-surface preflight
// (`FrameworkExportSurface`, the #942 surface, fail-open) over the spec's
// Key Entities and refuses with a `--> fix:` rename suggestion BEFORE any
// artifact is written. The run-time detection itself is untouched — this
// plan-time gate is an earlier net, not a weaker one.
//
// Surface resolution in tests: the in-process suites seed the fixture's
// `.dart_tool/package_config.json` with a `zuraffa` entry — the PRIMARY
// resolution path, and the one every real project hits (the config `pub
// get` writes). Under `dart test` the script-path fallback is
// unresolvable BY TEST-HARNESS CONSTRUCTION (`Platform.script` is a temp
// kernel dill), which the fail-open test below pins deliberately: no
// resolvable surface → no gate → no false refusal.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory tmpDir;
  late String featureDir;
  const featureName = '013-agent-modes-killswitch';

  List<String> args(List<String> rest) => [
    'tdd',
    ...rest,
    '--project',
    tmpDir.path,
  ];

  Future<String> runPlan() async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args(['plan', featureName]));
  }

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('bug993_clash_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    await Directory(featureDir).create(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    exitCode = 0;
  });

  /// Seeds the fixture's `.dart_tool/package_config.json` with a
  /// `zuraffa` package entry pointing at the CLI's own checkout. This is
  /// the primary `FrameworkExportSurface` resolution path — the config
  /// every real project gets from `pub get` — so the gate behaves here
  /// exactly as it does for a real user project that depends on zuraffa.
  void seedZuraffaPackageConfig() {
    final dartTool = Directory(p.join(tmpDir.path, '.dart_tool'))
      ..createSync(recursive: true);
    File(p.join(dartTool.path, 'package_config.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'configVersion': 2,
        'packages': [
          {
            'name': 'zuraffa',
            'rootUri': Uri.file(zfaProjectRoot).toString(),
            'packageUri': 'lib/',
            'languageVersion': '3.11',
          },
        ],
      }),
    );
  }

  /// Writes a spec that is otherwise gate-clean (template version pinned,
  /// every FR/AC statement maps to a behavior row) and declares [entities]
  /// as the Key Entities section body.
  Future<void> writeSpec(String entities) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Spec: $featureName

## Acceptance Scenarios

1. **Given** a running agent **When** the kill switch trips **Then** the agent stops accepting missions

## Functional Requirements

- **FR-001**: The system MUST stop accepting missions when the kill switch trips

### Key Entities

$entities
''');
  }

  group(
    '#993 — plan refuses Key Entities that collide with zuraffa exports',
    () {
      test('plan exits 2 on a zuraffa-export entity name with a --> fix: '
          'rename suggestion and writes no artifacts', () async {
        seedZuraffaPackageConfig();
        await writeSpec(
          '- **AgentState**: Mission-scoped session state persisted for '
          'resume. Contains `missionId: String`.',
        );

        final out = await runPlan();

        expect(
          exitCode,
          2,
          reason:
              'the AgentState/zuraffa-export clash must be caught at plan '
              'time, not at run-time phase-0:\n$out',
        );
        expect(out, contains('AgentState'), reason: out);
        expect(out, contains('export'), reason: 'clash source named: $out');
        expect(
          out,
          contains('--> fix:'),
          reason:
              'VISION §4 errors-are-an-API: the refusal must carry a '
              'machine-actionable fix line:\n$out',
        );
        expect(out, contains('rename'), reason: 'fix contract: $out');
        // The refusal leaves the feature directory artifact-free: a plan
        // that knows the run will halt must not emit a test list that
        // claims the loop is drivable.
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isFalse,
          reason: 'a clashing plan must not write a test list',
        );
        expect(
          File(p.join(featureDir, 'tdd', 'traceability.md')).existsSync(),
          isFalse,
          reason: 'a clashing plan must not write a traceability matrix',
        );
      });

      test(
        'the refusal names the framework file the clash comes from',
        () async {
          seedZuraffaPackageConfig();
          await writeSpec('- **AgentState**: Mission-scoped session state.');

          final out = await runPlan();

          expect(
            out,
            contains('package:zuraffa/src/agent/runtime/state_storage.dart'),
            reason:
                'the clash source pins the collision for the spec author:\n'
                '$out',
          );
        },
      );

      test('a mixed section refuses on the colliding entity', () async {
        seedZuraffaPackageConfig();
        await writeSpec('''
- **AgentState**: Mission-scoped session state.
- **KillSwitchLog**: Append-only audit log of kill switch trips.
''');

        final out = await runPlan();

        expect(exitCode, 2, reason: out);
        expect(out, contains('AgentState'), reason: out);
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isFalse,
          reason:
              'one clash refuses the whole plan: phase-0 would halt '
              'on this entity regardless of the clean ones',
        );
      });

      test('a non-colliding entity name still plans successfully (no false '
          'refusal with a resolvable surface)', () async {
        seedZuraffaPackageConfig();
        await writeSpec(
          '- **AgentSessionSnapshot**: Mission-scoped session state '
          'persisted for resume. Contains `missionId: String`.',
        );

        final out = await runPlan();

        expect(
          exitCode,
          0,
          reason: 'the gate must not false-refuse clean names:\n$out',
        );
        final list = File(p.join(featureDir, 'tdd', 'test-list.md'));
        expect(list.existsSync(), isTrue, reason: out);
        final content = list.readAsStringSync();
        expect(content, contains('## Key entities'));
        expect(content, contains('| AgentSessionSnapshot |'));
      });

      test('a spec without Key Entities is unaffected (gate skips the empty '
          'section even with a resolvable surface)', () async {
        seedZuraffaPackageConfig();
        await writeSpec('');

        final out = await runPlan();

        expect(exitCode, 0, reason: out);
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isTrue,
          reason: out,
        );
      });

      test('an unresolvable export surface never false-refuses (fail-open '
          'contract)', () async {
        // NO package_config seeded: under `dart test` the script-path
        // fallback is dead (Platform.script is a temp kernel dill), so the
        // surface is unresolvable — exactly the environment the #942
        // fail-open contract protects. The clashing name must plan cleanly
        // rather than be refused on a surface nobody could resolve.
        await writeSpec('- **AgentState**: Mission-scoped session state.');

        final out = await runPlan();

        expect(
          exitCode,
          0,
          reason: 'fail-open: an unresolvable surface must not refuse:\n$out',
        );
        expect(
          File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
          isTrue,
          reason: out,
        );
      });
    },
  );

  group('#993 — end-to-end: the real CLI refuses the clashing plan', () {
    test('zfa tdd plan (subprocess) exits 2 with the --> fix: rename '
        'suggestion and writes no test list', () async {
      seedZuraffaPackageConfig();
      await writeSpec(
        '- **AgentState**: Mission-scoped session state persisted for '
        'resume. Contains `missionId: String`.',
      );

      final result = await runZfaSource([
        'tdd',
        'plan',
        featureName,
        '--project',
        tmpDir.path,
      ], workingDirectory: tmpDir.path);
      final out = '${result.stdout}${result.stderr}';

      expect(
        result.exitCode,
        2,
        reason: 'the real CLI must refuse at plan time:\n$out',
      );
      expect(out, contains('AgentState'), reason: out);
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('rename'), reason: out);
      expect(
        out,
        contains('package:zuraffa/src/agent/runtime/state_storage.dart'),
        reason: out,
      );
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isFalse,
        reason: 'no test list may survive the refusal:\n$out',
      );
    });
  });
}
