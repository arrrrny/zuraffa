// Bug #1044 — `zfa tdd verify`'s mutation audit spawns `dart test` LITERALLY
// (preflight + the scoped mutation config's test command), so Flutter
// features (widget tests importing package:flutter/*) can never pass the
// gate: `dart test` cannot load them and the audit reports a permanent
// `gate: preflight_red` with `mutation_was_run: false`.
//
// The project's TDD profile (`.specify/memory/tdd-profile.md`, written by
// `zfa tdd setup`) already declares the runner — `file: 'flutter test
// {file}'` for Flutter projects — but the auditor never reads it.
//
// Test tier: FAST (the preflight spawn is injected; no real processes).
//
// RED evidence (pre-fix master): every test below that expects a
// `flutter test` spawn fails — the auditor hardcodes `dart` in
// `_runPreflightTestFile` and `dart test $command` in
// `buildScopedMutationConfig`, regardless of the profile.
//
// Contract pinned here (remediation, minimal):
//   1. The auditor resolves the whole-file runner from the profile's
//      `file:` template; a project WITHOUT a profile keeps the pure-Dart
//      default (`dart test {file}`) — existing behavior preserved.
//   2. `--runner dart|flutter` (verify_command) overrides the profile.
//   3. The scoped mutation config's test command is built from the SAME
//      resolved template — mutants re-run under the profile's runner.
//   4. A profile present without a usable `file:` key, or a template
//      without `{file}`, is an honest NOT_ASSESSED with a `--> fix:` line
//      — never a silent fallback, never a crash.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

/// A scope pair on disk (registered artifacts + existing subject) and an
/// optional TDD profile — enough for the audit to reach the preflight.
({
  Directory tmpDir,
  String featureDir,
  List<List<String>> spawns,
  MutationAuditor auditor,
})
_harness({String? profileYaml, String? runnerTemplate, int exitCode = 0}) {
  final tmpDir = Directory.systemTemp.createTempSync('bug1044_runner_');
  final featureDir = p.join(tmpDir.path, 'specs', '090-bug-1044');
  File(p.join(tmpDir.path, 'lib', 'tdd', 'b_001_subject.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('int add(int a, int b) => a + b;\n');
  if (profileYaml != null) {
    File(p.join(tmpDir.path, '.specify', 'memory', 'tdd-profile.md'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(profileYaml);
  }
  File(p.join(featureDir, 'tdd', 'artifacts.json'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'feature': '090-bug-1044',
        'records': [
          {
            'behavior_id': 'B-001',
            'feature': '090-bug-1044',
            'source_criterion': 'FR-001',
            'test_path': 'test/tdd/b_001_test.dart',
            'subject_path': 'lib/tdd/b_001_subject.dart',
            'runnable_test_name': 'x::B-001::y',
            'test_ownership': 'created',
            'subject_ownership': 'created',
            'created_at': '2026-09-05T00:00:00.000Z',
          },
        ],
      }),
    );
  final spawns = <List<String>>[];
  final auditor = MutationAuditor(
    featureDir: featureDir,
    workingDirectory: tmpDir.path,
    runnerTemplate: runnerTemplate,
    spawnTest: (executable, args, workingDirectory, timeout) async {
      spawns.add([executable, ...args]);
      return ProcessResult(1, exitCode, 'All tests passed!', '');
    },
    runMutation: () async => throw UnimplementedError('not under test'),
  );
  return (
    tmpDir: tmpDir,
    featureDir: featureDir,
    spawns: spawns,
    auditor: auditor,
  );
}

const _flutterProfile = '''
## Keys (machine-readable)

```yaml
runner: flutter_test
single: 'flutter test {file} --plain-name "{name}"'
file: 'flutter test {file}'
suite: 'flutter test'
```
''';

const _dartProfile = '''
## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
file: 'dart test {file}'
suite: 'dart test'
```
''';

void main() {
  test('issue #1044: a Flutter profile file: template drives the preflight '
      'spawn — flutter test <file>, not dart test <file>', () async {
    final h = _harness(profileYaml: _flutterProfile);
    addTearDown(() => h.tmpDir.deleteSync(recursive: true));

    await h.auditor.run();

    expect(h.spawns, isNotEmpty, reason: 'the preflight must run the file');
    expect(h.spawns.first, ['flutter', 'test', 'test/tdd/b_001_test.dart']);
  });

  test(
    'no profile → the pure-Dart default is preserved (dart test <file>)',
    () async {
      final h = _harness();
      addTearDown(() => h.tmpDir.deleteSync(recursive: true));

      await h.auditor.run();

      expect(h.spawns, isNotEmpty);
      expect(h.spawns.first, ['dart', 'test', 'test/tdd/b_001_test.dart']);
    },
  );

  test('a dart profile keeps dart (profile-driven, not hardcoded)', () async {
    final h = _harness(profileYaml: _dartProfile);
    addTearDown(() => h.tmpDir.deleteSync(recursive: true));

    await h.auditor.run();

    expect(h.spawns.first, ['dart', 'test', 'test/tdd/b_001_test.dart']);
  });

  test('issue #1044: the scoped mutation config runs mutants under the '
      "profile's runner (flutter, not dart)", () async {
    // The default mutation phase is bypassed when runMutation is
    // injected (bug #924: the config is ensured ONLY for the default
    // phase), so the template→config wiring is pinned at the unit level:
    // the same resolved template the preflight spawned must also build
    // the mutant command.
    final xml = buildScopedMutationConfig(
      subjectPaths: ['lib/tdd/b_001_subject.dart'],
      testPaths: ['test/tdd/b_001_test.dart'],
      fileTemplate: 'flutter test {file}',
    );
    expect(
      xml,
      contains(
        '<command group="test" expected-return="0" '
        'working-directory=".">flutter test test/tdd/b_001_test.dart</command>',
      ),
      reason: xml,
    );
    expect(xml, isNot(contains('dart test')), reason: xml);

    // Multiple test paths: first substituted into the template, the rest
    // appended (the documented batch convention).
    final multi = buildScopedMutationConfig(
      subjectPaths: const [],
      testPaths: ['test/tdd/a_test.dart', 'test/tdd/b_test.dart'],
      fileTemplate: 'flutter test {file}',
    );
    expect(
      multi,
      contains('flutter test test/tdd/a_test.dart test/tdd/b_test.dart'),
      reason: multi,
    );
  });

  test(
    'issue #1044: --runner (runnerTemplate) overrides the profile',
    () async {
      final h = _harness(
        profileYaml: _dartProfile,
        runnerTemplate: 'flutter test {file}',
      );
      addTearDown(() => h.tmpDir.deleteSync(recursive: true));

      await h.auditor.run();

      expect(h.spawns.first, ['flutter', 'test', 'test/tdd/b_001_test.dart']);
    },
  );

  test('a profile present without a file: key is an honest NOT_ASSESSED '
      'with a --> fix: line — no silent fallback, no crash', () async {
    final brokenProfile = '''
## Keys (machine-readable)

```yaml
runner: flutter_test
single: 'flutter test {file} --plain-name "{name}"'
suite: 'flutter test'
```
''';
    final h = _harness(profileYaml: brokenProfile);
    addTearDown(() => h.tmpDir.deleteSync(recursive: true));

    final report = await h.auditor.run();

    expect(report.gate.label, contains('not_assessed'));
    expect(report.notAssessedReason, contains('--> fix:'));
    expect(h.spawns, isEmpty, reason: 'nothing may run on a broken profile');
  });

  test('a file: template without {file} is an honest NOT_ASSESSED with a '
      '--> fix: line', () async {
    final h = _harness(
      profileYaml: _flutterProfile.replaceFirst(
        "file: 'flutter test {file}'",
        "file: 'flutter test'",
      ),
    );
    addTearDown(() => h.tmpDir.deleteSync(recursive: true));

    final report = await h.auditor.run();

    expect(report.gate.label, contains('not_assessed'));
    expect(report.notAssessedReason, contains('{file}'));
    expect(report.notAssessedReason, contains('--> fix:'));
    expect(h.spawns, isEmpty);
  });

  group(
    'CLI — the --runner flag validates before anything resolves (#1044)',
    () {
      test("a --runner value other than dart|flutter is a usage error "
          "(exit 64) and never starts an audit", () async {
        // The flag is the operator's override surface; a typo'd value must
        // fail loudly at the boundary (exit 64 + the fix line on stderr)
        // instead of falling through to a guessed runner or a profile
        // resolution that could mask the mistake.
        final tmpDir = Directory.systemTemp.createTempSync('bug1044_cli_');
        addTearDown(() => tmpDir.deleteSync(recursive: true));

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify',
          '--project',
          tmpDir.path,
          '--runner',
          'flutter_test',
        ]);

        expect(exitCode, 64, reason: out);
        // The audit never started: no scope derivation, no preflight, no
        // report (the audit-start banner is the first observable step).
        expect(out, isNot(contains('running mutation audit')), reason: out);
      });
    },
  );
}
