@Tags(['slow'])
// Issue #1407 — the make's analyze gate must gate on ERRORS only.
//
// The make plan's terminal `build` step runs `zfa build`, whose analyze
// gate (issue #1035) refuses the tree on errors OR warnings. A
// warnings-only refusal (0 errors + N warnings) then reaches the make's
// #737/#942 per-behavior guard, which grades the make on the behavior's
// own target test — a skin-lane widget behavior mid-rebuild can still be
// red (the sanctioned handcraft seam), so the make stopped
// `outcome=generation-error` on a warning the engine lane's own green
// receipt had accepted. Cross-lane warning coupling.
//
// The fix (same file as the make): the make re-grades the failed terminal
// build step BEFORE the tolerance — when the build output proves the
// refusal was the analyze gate's own verdict with 0 errors and >=1
// warning (cross-checked through the shared `BuildCommand` parser), the
// warnings are logged as non-blocking and the make proceeds through its
// normal flow. Only analyzer errors keep the honest stop. A project opts
// back into the legacy warnings-blocking strictness via the TDD profile's
// machine-readable Keys block (`analyze-gate: warnings-blocking`).
//
// Drives the public CLI surface (`zfa tdd make`) against a TddFixture
// temp project; the pipeline runs through the fake zfa bin (real `dart
// test` children), per the make_command_test.dart conventions.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd make`, pinning the project root
/// (mirrors the helper in make_command_test.dart).
List<String> makeArgs(
  TddFixture fx, {
  String? id,
  String? zfaBin,
  String? feature,
}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (feature != null) args.addAll(['--feature', feature]);
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (id != null) args.add(id);
  return args;
}

/// The build step's analyze-gate refusal on WARNINGS ONLY — the exact
/// real-world shape from the issue (zik_zak_v2 login, skin lane W3):
/// `dart analyze` reports 0 errors and 1 pre-existing warning (an unused
/// import left in an engine-lane test), and the build command's gate
/// refuses with the "does not compile cleanly" message.
const _warningsOnlyBuildStdout = [
  '   warning - test/tdd/login/u1_test.dart:3:8 - Unused import: package:test/test.dart. - unused_import',
  '❌ dart analyze reported 0 error(s) and 1 warning(s) — generated code does not compile cleanly.',
];

/// The same refusal shape carrying analyzer ERRORS (the #942 class: the
/// generated tree does not compile).
const _errorsBuildStdout = [
  '   error - lib/src/data/datasources/credentials/credentials_mock_datasource.dart:21:10 - The name Credentials is defined in two libraries. - ambiguous_import',
  '   error - lib/src/data/datasources/credentials/credentials_datasource.dart:5:8 - The name Credentials is defined in two libraries. - ambiguous_import',
  '❌ dart analyze reported 2 error(s) and 0 warning(s) — generated code does not compile cleanly.',
];

const _unitDescription = 'returns 42 when invoked with no args';
const _widgetDescription = 'the login page shows a welcome message';

/// The implemented view-builder the fake pipeline's `tdd view` step
/// writes (the deterministic minimal view the real command renders) —
/// pure-Dart stand-in for the Flutter widget, per the #939 test shape.
String _implementedView(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
library;

class Widget {
  const Widget();
}

Widget $symbol() => const Widget();
''';
}

/// The widget-kind target test: the honest red is the view-builder still
/// throwing (the #830 taxonomy), green once the view step implements it.
String _widgetTargetTest(String id, String description) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
import 'package:test/test.dart';

import '../lib/${symbol}_subject.dart' as subject;

void main() {
  test("$description", () {
    final Object? built = (() {
      try {
        return subject.$symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(built, isNot(isA<UnimplementedError>()));
  });
}
''';
}

/// The gen-shaped view-builder stub SubjectWriter emits for widget-kind
/// rows (bug #830 / issue #959 inert shape).
String _widgetStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation).
library;

/// View-builder subject for behavior $id.
Widget $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// Inject (or overwrite) an `analyze-gate:` key in the fixture profile's
/// machine-readable Keys block. Passing null REMOVES any such key (the
/// default absent-key shape).
Future<void> setProfileGate(TddFixture fx, String? value) async {
  final path = p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md');
  final raw = await File(path).readAsString();
  final stripped = raw.replaceAll(
    RegExp(r'^analyze-gate:.*$\n?', multiLine: true),
    '',
  );
  if (value == null) {
    await File(path).writeAsString(stripped);
    return;
  }
  await File(path).writeAsString(
    stripped.replaceFirst('```yaml', "```yaml\nanalyze-gate: '$value'"),
  );
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1407 — the make gate is errors-only (warnings non-blocking)', () {
    // SC-004 / A-1407-2 ("match the skin lane's byte-for-byte"): the
    // skin-lane verdict line captured by A-1407-1, compared against the
    // unit-lane verdict in U-1407-4 (package:test runs group tests in
    // declaration order, so A-1407-1 has always run first).
    var skinLaneVerdict = '';
    test('A-1407-1: a skin-lane widget make refused 0-errors+1-warning '
        'completes green — the warning is logged non-blocking, the outcome '
        'is never a failed-build nor a generation failure', () async {
      // The issue's exact real-world shape: skin lane W3, engine-lane
      // pre-existing unused-import warning, terminal build step refused
      // by the analyze gate. The view step flips W3's test green, so
      // nothing about THIS behavior is red — the warning must not block.
      await fx.seedTestList([
        (
          id: 'W3',
          description: _widgetDescription,
          traces: 'FR-1',
          state: 'PENDING',
          kind: 'widget',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'W3',
        description: _widgetDescription,
        subjectContent: _widgetStub('W3'),
        testContent: _widgetTargetTest('W3', _widgetDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd view': fx.overwriteSubjectCommands('W3', _implementedView('W3')),
        },
        stdoutByArgv: {'build': _warningsOnlyBuildStdout},
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'W3', zfaBin: zfaBin),
      );

      // Pre-fix: the refusal reaches the #737 tolerance (0 errors passes
      // its #942 gate) and the make records green-with-failed-build — a
      // failed-build label a mere warning must never produce.
      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=W3 outcome=green feature=${fx.featureName}'),
        reason: 'out:\n$out',
      );
      expect(out, isNot(contains('green-with-failed-build')));
      expect(out, isNot(contains('outcome=generation-error')));
      // The warnings are logged with the non-blocking verdict (FR-002):
      // the counts, the policy, and the offending line.
      expect(
        out,
        contains('warnings are non-blocking (issue #1407'),
        reason: 'out:\n$out',
      );
      // Capture the FULL verdict line (not just a shared substring) — the
      // unit lane's U-1407-4 compares it byte-for-byte (SC-004).
      skinLaneVerdict = out
          .split('\n')
          .singleWhere((l) => l.contains('warnings are non-blocking'));
      expect(
        skinLaneVerdict,
        contains('0 error(s), 1 warning(s)'),
        reason: 'the verdict names the counts (out:\n$out)',
      );
      expect(
        out,
        contains('unused_import'),
        reason: 'the analyzer warning line itself is logged (out:\n$out)',
      );
      // The make genuinely completed: green evidence appended.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: W3 (green)'));
    });

    test('U-1407-4 / A-1407-2: an engine-lane unit make under the identical '
        'refusal completes green with the same verdict — the default gate '
        '(no analyze-gate key) is errors-only', () async {
      await fx.seedCertifiedRed(
        id: 'U3',
        description: _unitDescription,
        testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U3',
            TddFixture.subjectReturning('U3', 42),
          ),
        },
        stdoutByArgv: {'build': _warningsOnlyBuildStdout},
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=green feature=${fx.featureName}'),
        reason: 'out:\n$out',
      );
      expect(out, isNot(contains('green-with-failed-build')));
      // The full verdict line, with the counts pinned (the count half the
      // substring check left unpinned), and the SC-004 byte-for-byte
      // cross-lane equality against A-1407-1's skin-lane verdict.
      final verdict = out
          .split('\n')
          .singleWhere((l) => l.contains('warnings are non-blocking'));
      expect(
        verdict,
        contains('0 error(s), 1 warning(s)'),
        reason: 'the verdict names the counts (out:\n$out)',
      );
      expect(verdict, equals(skinLaneVerdict));
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U3 (green)'));
    });

    test('U-1407-1: a warnings-only refusal with a still-red target test '
        'keeps the honest generation-error — the red test decides, never '
        'the warning', () async {
      // The func scaffold does NOT implement the subject: the behavior's
      // own test stays red. The warning must not change this verdict in
      // either direction (no green-wash, no extra refusal cause).
      await fx.seedCertifiedRed(
        id: 'U3',
        description: _unitDescription,
        testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        stdoutByArgv: {'build': _warningsOnlyBuildStdout},
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=generation-error'),
        reason: 'out:\n$out',
      );
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: U3 (green)')));
      // The #1036 failed-make contract: the subject survives untouched
      // (the stub was never implemented, and the failed make restores it).
      final subject = await File(fx.subjectPathOf('U3')).readAsString();
      expect(subject, contains('0;'));
    });

    test('U-1407-2: a build verdict carrying analyzer errors keeps the #942 '
        'refusal byte-identical — only errors stop the make', () async {
      await fx.seedCertifiedRed(
        id: 'U3',
        description: _unitDescription,
        testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U3',
            TddFixture.subjectReturning('U3', 42),
          ),
        },
        stdoutByArgv: {'build': _errorsBuildStdout},
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=generation-error'),
        reason: 'out:\n$out',
      );
      expect(
        out,
        contains('analyzer error(s)'),
        reason: 'the #942 refusal names why (out:\n$out)',
      );
      expect(out, isNot(contains('warnings are non-blocking')));
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: U3 (green)')));
    });

    test('U-1407-3: analyze-gate warnings-blocking in the profile restores '
        'the pre-#1407 grading (green-with-failed-build)', () async {
      await setProfileGate(fx, 'warnings-blocking');
      await fx.seedCertifiedRed(
        id: 'U3',
        description: _unitDescription,
        testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U3',
            TddFixture.subjectReturning('U3', 42),
          ),
        },
        stdoutByArgv: {'build': _warningsOnlyBuildStdout},
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      // The opted-in project gets exactly the legacy behavior: the
      // warnings-only refusal reaches the #737/#942 tolerance, whose
      // passing target test yields green-with-failed-build.
      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains(
          'make: behavior=U3 outcome=green-with-failed-build '
          'feature=${fx.featureName}',
        ),
        reason: 'out:\n$out',
      );
      expect(out, isNot(contains('warnings are non-blocking')));
    });

    test('U-1407-5: an explicit errors-only value and an unrecognized value '
        'both behave like the default (the opt-in is exactly '
        'warnings-blocking)', () async {
      for (final value in ['errors-only', 'strict-everything']) {
        await setProfileGate(fx, value);
        await fx.seedCertifiedRed(
          id: 'U3',
          description: _unitDescription,
          testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'tdd func': fx.overwriteSubjectCommands(
              'U3',
              TddFixture.subjectReturning('U3', 42),
            ),
          },
          stdoutByArgv: {'build': _warningsOnlyBuildStdout},
          exitByArgv: {'build': 1},
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U3', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: 'gate=$value out:\n$out');
        expect(
          out,
          contains('make: behavior=U3 outcome=green feature=${fx.featureName}'),
          reason: 'gate=$value out:\n$out',
        );
        expect(out, contains('warnings are non-blocking (issue #1407'));
      }
    });

    test('A-1407-3: an already-green sibling takes the skip transition — '
        'the gate never runs there, matching the normal transition\'s '
        'non-blocking warning strictness', () async {
      // The behavior's test passes on disk (the drift check is green) so
      // the make takes the #694 skip transition: no pipeline, no build,
      // no gate — outcome=skipped, exit 0.
      await fx.seedCertifiedRed(
        id: 'U3',
        description: _unitDescription,
        testContent: TddFixture.greenTest(_unitDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=skipped feature=${fx.featureName}'),
        reason: 'out:\n$out',
      );
    });

    test('U-1407-6: attribution edges — a build failure without the gate '
        'message keeps the tolerance path; a 0-error message over raw '
        'error lines keeps the honest stop; voluminous warnings log a '
        'capped sample with a remainder', () async {
      // (a) No gate message: a plain build failure (no analyzer lines)
      // still reaches the #737 tolerance — green-with-failed-build.
      {
        await fx.seedCertifiedRed(
          id: 'U3',
          description: _unitDescription,
          testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'tdd func': fx.overwriteSubjectCommands(
              'U3',
              TddFixture.subjectReturning('U3', 42),
            ),
          },
          stdoutByArgv: {
            'build': ['build_runner failed for unrelated pre-existing reasons'],
          },
          exitByArgv: {'build': 1},
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U3', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: 'out:\n$out');
        expect(
          out,
          contains('outcome=green-with-failed-build'),
          reason: 'out:\n$out',
        );
        expect(out, isNot(contains('warnings are non-blocking')));
      }

      // (b) The gate message claims 0 errors but the raw output carries
      // error lines: the shared parser wins — the honest stop stands.
      {
        await fx.seedCertifiedRed(
          id: 'U3',
          description: _unitDescription,
          testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'tdd func': fx.overwriteSubjectCommands(
              'U3',
              TddFixture.subjectReturning('U3', 42),
            ),
          },
          stdoutByArgv: {
            'build': [
              ..._errorsBuildStdout.take(1),
              '❌ dart analyze reported 0 error(s) and 1 warning(s) — generated code does not compile cleanly.',
            ],
          },
          exitByArgv: {'build': 1},
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U3', zfaBin: zfaBin),
        );

        expect(exitCode, isNot(0), reason: 'out:\n$out');
        expect(out, contains('outcome=generation-error'), reason: 'out:\n$out');
        expect(out, isNot(contains('warnings are non-blocking')));
      }

      // (c) Voluminous warnings: the verdict names the full count and the
      // log carries a capped sample plus a remainder line.
      {
        await fx.seedCertifiedRed(
          id: 'U3',
          description: _unitDescription,
          testContent: TddFixture.subjectDrivenTest('U3', _unitDescription),
        );
        final manyWarnings = List<String>.generate(
          12,
          (i) =>
              '   warning - test/tdd/login/u${i}_test.dart:${i + 1}:8 - '
              'Unused import: package:test/test.dart. - unused_import',
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'tdd func': fx.overwriteSubjectCommands(
              'U3',
              TddFixture.subjectReturning('U3', 42),
            ),
          },
          stdoutByArgv: {
            'build': [
              ...manyWarnings,
              '❌ dart analyze reported 0 error(s) and 12 warning(s) — generated code does not compile cleanly.',
            ],
          },
          exitByArgv: {'build': 1},
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U3', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: 'out:\n$out');
        expect(out, contains('0 error(s), 12 warning(s)'));
        expect(out, contains('warnings are non-blocking (issue #1407'));
        // Capped sample: 10 of the 12 lines logged, remainder named.
        expect(out, contains('u0_test.dart'));
        expect(out, contains('u9_test.dart'));
        expect(out, isNot(contains('u10_test.dart:11')));
        expect(out, contains('2 more warning(s)'));
      }
    });
  });
}
