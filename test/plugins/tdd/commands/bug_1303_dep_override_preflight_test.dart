// Bug #1303 — tdd make / tdd run / zfa build honest classification for
// stale `dependency_overrides` path targets.
//
// Root cause (issue #1303): no preflight validates that
// `dependency_overrides[*].path` values resolve to directories holding a
// `pubspec.yaml` before the pipeline spends minutes compiling. A stale
// path surfaces as a raw exit-255 version-solving dump buried mid-log,
// classified `generation-error`, and the "retry with clean cache"
// fallback burns a full rebuild on a resolution error no cache clean can
// fix.
//
// Fix contract (issue #1303):
//   1. `tdd make` and `tdd run` preflight every override path BEFORE any
//      work: invalid → `❌ preflight:` line + `--> fix:` line, exit 3
//      (SPEC 917 drift class — a stale override is corrupt project
//      state), zero steps spawned.
//   2. `zfa build` skips the clean-cache retry when the failure output
//      carries a pub RESOLUTION signature (`version solving failed` /
//      `No pubspec.yaml found for package`) — cache state cannot fix
//      resolution. Non-resolution failures keep the retry (untouched).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const featureName = '130-dep-override-preflight';

const kPreflightMarker = '❌ preflight: dependency_overrides[';
const kFixLine =
    '--> fix: correct the override path or remove the entry from '
    'pubspec.yaml, then re-run';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug1303_fixture_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  /// Seeds the temp project with a pubspec whose dependency_overrides
  /// carry [overrideBody], plus the spec/test-list shape the driving
  /// commands resolve.
  Future<void> seedProject({
    String overrideBody = '''
  zuraffa:
    path: ../..
  zuraffa_flutter:
    path: ../../zuraffa_flutter
''',
  }) async {
    Directory(
      p.join(tmpDir.path, 'specs', featureName, 'tdd'),
    ).createSync(recursive: true);
    await File(
      p.join(tmpDir.path, 'specs', featureName, 'tdd', 'test-list.md'),
    ).writeAsString('''
| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| A1 | renders the dashboard shell on mount | AC-1 | unit | PENDING | subject_a1 |
''');
    await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: login_demo
environment:
  sdk: ^3.11.0
dependency_overrides:
$overrideBody
''');
  }

  group('bug1303: tdd make preflight', () {
    test('stale path override refuses BEFORE target resolution: exit 3, '
        'preflight + fix lines, zero generation', () async {
      await seedProject();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'A1',
        '--project',
        tmpDir.path,
      ]);

      expect(
        exitCode,
        3,
        reason:
            'a stale override is corrupt project state — the SPEC 917 '
            'drift class, exit 3. stdout:\n$out',
      );
      expect(out, contains(kPreflightMarker));
      expect(out, contains('path "../../zuraffa_flutter"'));
      expect(out, contains('(no pubspec.yaml'));
      expect(out, contains('$kFixLine `zfa tdd make`'));
      expect(out, contains('outcome=preflight-red'));
      // Refusal happens BEFORE any target resolution / generation:
      // no behavior resolution banner, no pipeline work.
      expect(
        out,
        isNot(contains('zfa tdd make: behavior A1')),
        reason:
            'the preflight must stop the make before any generation '
            'spawns (issue #1303: no more mid-pipeline dumps)',
      );
    });

    test('a resolvable override does NOT trip the preflight — the make '
        'proceeds past the gate', () async {
      // The override names the fixture root ITSELF (a directory that
      // exists and carries a pubspec.yaml — resolvable).
      await seedProject(
        overrideBody: '''
  zuraffa:
    path: .
''',
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'A1',
        '--project',
        tmpDir.path,
      ]);

      expect(
        out,
        isNot(contains(kPreflightMarker)),
        reason: 'a valid path override must pass the gate. stdout:\n$out',
      );
      expect(
        exitCode,
        isNot(3),
        reason:
            'the drift exit belongs to the preflight refusal only — '
            'the make failed (if at all) for fixture reasons, not override '
            'reasons. stdout:\n$out',
      );
    });
  });

  group('bug1303: tdd run preflight', () {
    test('stale path override stops the meta run before ANY lane step: '
        'exit 3, corrupt-state summary, no [run] lines', () async {
      await seedProject();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        featureName,
        '--project',
        tmpDir.path,
      ]);

      expect(
        exitCode,
        3,
        reason:
            'run\'s corrupt-state class (issue #1303: exit 3 for the '
            'drift verdict). stdout:\n$out',
      );
      expect(out, contains(kPreflightMarker));
      expect(out, contains('$kFixLine `zfa tdd run`'));
      expect(
        out,
        contains('result=corrupt-state'),
        reason: 'the FR-009 summary line must carry the drift verdict',
      );
      expect(
        out,
        isNot(contains('[run] ')),
        reason:
            'no step may spawn on a refused run (zero steps, '
            'preflight_red)',
      );
    });
  });
}
