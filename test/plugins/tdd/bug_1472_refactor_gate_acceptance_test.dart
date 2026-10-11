@Tags(['slow', 'integration'])
// Issue #1472 — acceptance: the refactor step survives a warnings-only
// build-gate refusal through the public CLI surface.
//
// Reproduction from the issue: hand-implement a gen'd subject leaving an
// unused import; `zfa tdd run`'s refactor step runs the pass registry
// (build → format → fix); the build pass's analyze gate refuses with
// `0 error(s) and N warning(s)`; the registry misfire-stops (`pass "build"
// failed — misfire-stop`); the dart fix pass that would remove the lint
// never runs; the run surfaces `runner-error`.
//
// Drives `zfa tdd refactor` via CliRunner against a TddFixture temp
// project; the build pass runs the fixture's fake system zfa (real `dart
// test` children for the preflight/re-proof), per the refactor_command_test
// and bug_1407 conventions. The `--zfa-bin` override pins the build pass
// entrypoint so the default resolution (and its #1472 version probe) never
// fires here.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The build step's analyze-gate refusal on WARNINGS ONLY — the issue's
/// exact transcript shape (`pass "build" failed — misfire-stop` upstream):
/// `dart analyze` reports 0 errors and warnings the dart fix pass would
/// clean, and the build command's gate refuses with the "does not compile
/// cleanly" message.
const _warningsOnlyBuildStdout = [
  '   warning - lib/tdd/login/u8_subject.dart:31:8 - Unused import: '
      'package:uuid/uuid.dart. - unused_import',
  '❌ dart analyze reported 0 error(s) and 2 warning(s) — generated code '
      'does not compile cleanly.',
];

/// The same refusal shape carrying analyzer ERRORS (the tree does not
/// compile — must keep the honest runner-error stop, SC-2).
const _errorsBuildStdout = [
  '   error - lib/tdd/login/u8_subject.dart:31:8 - Undefined name '
      "'Widget'. - undefined_identifier",
  '❌ dart analyze reported 1 error(s) and 0 warning(s) — generated code '
      'does not compile cleanly.',
];

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A-1472-1: a warnings-only build-gate refusal does not deadlock the '
      'refactor — outcome is clean/refactored, exit 0, fix pass ran', () async {
    // The seeded subject carries a real fixable lint (an unused import) —
    // the issue's exact deadlock shape — so the case proves the `dart fix`
    // pass RAN and changed the tree, not merely that the pre-fix error
    // message is absent.
    await fx.seedGreenSuite(
      libContent: "import 'dart:math';\n\nint answer() {\n  return 42;\n}\n",
    );
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      stdoutByArgv: {'build': _warningsOnlyBuildStdout},
      exitByArgv: {'build': 1},
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
    ]);

    // Pre-fix: `pass "build" failed — misfire-stop.` + outcome=runner-error
    // + exit 1 — the deadlock. Post-fix: the registry continues through
    // format → fix and the re-proof decides the outcome (green here).
    expect(
      out,
      contains(
        RegExp(r'refactor: feature=\S+ outcome=(clean|refactored) applied=\d+'),
      ),
      reason: 'out:\n$out',
    );
    expect(out, isNot(contains('outcome=runner-error')));
    // SC-3: the accurate counts are surfaced on the transcript.
    expect(out, contains('0 error(s), 2 warning(s)'));
    // Both follow-on passes reached the transcript, and the fix pass really
    // changed the tree (applied >= 1) — the deadlock's whole point.
    expect(out, contains('pass: format'), reason: 'out:\n$out');
    expect(out, contains('pass: fix'), reason: 'out:\n$out');
    expect(
      out,
      contains(
        RegExp(r'refactor: feature=\S+ outcome=refactored applied=[1-9]\d*'),
      ),
      reason: 'the dart fix pass must have applied a change:\n$out',
    );
    expect(exitCode, 0, reason: 'out:\n$out');
  });

  test('A-1472-2: a build-gate refusal carrying ERRORS still misfire-stops '
      'runner-error (SC-2 — compile errors are never tolerated)', () async {
    await fx.seedGreenSuite();
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      stdoutByArgv: {'build': _errorsBuildStdout},
      exitByArgv: {'build': 1},
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
    ]);

    expect(out, contains('pass "build" failed — misfire-stop.'));
    expect(out, contains('outcome=runner-error'));
    expect(exitCode, isNot(0));
  });

  test('A-1472-3: `analyze-gate: warnings-blocking` in the TDD profile '
      'restores the legacy refusal (SC-5 — the #1407 opt-in honored here '
      'too)', () async {
    await fx.seedGreenSuite();
    final profilePath = File('${fx.root.path}/.specify/memory/tdd-profile.md');
    await profilePath.writeAsString(
      (await profilePath.readAsString()).replaceFirst(
        '```yaml',
        "```yaml\nanalyze-gate: 'warnings-blocking'",
      ),
    );
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      stdoutByArgv: {'build': _warningsOnlyBuildStdout},
      exitByArgv: {'build': 1},
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'refactor',
      '--project',
      fx.root.path,
      '--zfa-bin',
      zfaBin,
    ]);

    expect(out, contains('pass "build" failed — misfire-stop.'));
    expect(out, contains('outcome=runner-error'));
    expect(exitCode, isNot(0));
  });
}
