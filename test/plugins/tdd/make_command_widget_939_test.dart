@Tags(['slow'])
// Make-level tests for the widget make path (issue #939): a widget-kind
// behavior's `zfa tdd make` routes to the view-builder lane — a
// deterministic `tdd view <id> --feature <f>` generation step + `build`
// — instead of dead-ending `unexpressible` with a WRONG kind label
// (`behavior "A1" is unit-kind` for a widget row).
//
// Drives the public CLI surface (`zfa tdd make`) against a TddFixture
// whose registry carries a widget-kind behavior with the gen-shaped
// view-builder stub SubjectWriter emits (bug #830). The pipeline's
// `tdd view` step runs through the fake zfa bin (side effect: writes the
// implemented view-builder), mirroring the composition-fallback tests.
library;

import 'dart:io';

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

const _widgetDescription =
    "the login page shows 'Welcome back' with a sign in button";

const _implementedView = '''
library;

class Widget {
  const Widget();
}

/// The implemented view-builder (the fake pipeline's side effect): the
/// deterministic minimal view the real `zfa tdd view` command renders.
Widget subject_a_100() => const Widget();
''';

/// The widget-kind target test: the honest-red capture the generated
/// widget test applies (issue #830 taxonomy) in pure-Dart fixture form —
/// the view-builder must stop throwing UnimplementedError.
String widgetTargetTest(String description) =>
    '''
import 'package:test/test.dart';

import '../lib/a_100_subject.dart' as subject;

void main() {
  // Double-quoted title: the description carries single quotes (the
  // scenario literals the generated widget test's finders assert).
  test("$description", () {
    final Object? built = (() {
      try {
        return subject.subject_a_100();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(built, isNot(isA<UnimplementedError>()));
  });
}
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('A14: a widget-kind behavior reaches green through the view-builder '
      'lane — plan logs the widget lane, runs tdd view + build in order, '
      'certifies the target test, exit 0', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: _widgetDescription,
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
      (
        id: 'U-100',
        description: 'unit behavior backing A-100',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'A-100',
      description: _widgetDescription,
      // The gen-shaped view-builder stub SubjectWriter emits for the
      // widget kind (bug #830).
      subjectContent: '''
// GENERATED STUB — `zfa tdd gen A-100` (spec 044-test-tdd-generation).
library;

/// View-builder subject for behavior A-100.
Widget subject_a_100() => throw UnimplementedError('subject_a_100 not implemented');
''',
      testContent: widgetTargetTest(_widgetDescription),
    );
    // The fake pipeline's `tdd view` step writes the implemented
    // view-builder (the deterministic view the real command renders in
    // production projects).
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'tdd view': fx.overwriteSubjectCommands('A-100', _implementedView),
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(
      makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
    );

    // Green certified, exit 0 — the widget lane no longer dead-ends.
    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('make: behavior=A-100 outcome=green feature=${fx.featureName}'),
    );
    // The widget lane is named (issue #939 observability).
    expect(out, contains('widget lane: view-builder generation'));
    // The fallback plan executed tdd view then build, in order.
    final log = await fx.readFakeZfaLog();
    expect(log, hasLength(2), reason: log.join('\n'));
    expect(log[0], contains('tdd view A-100'));
    expect(log[0], contains('--feature'));
    expect(log[1], 'build');
    // Both invocations are recorded in the green evidence (FR-010).
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    expect(cycleLog, contains('## Cycle: A-100 (green)'));
    expect(cycleLog, contains('tdd view A-100'));
  });

  test('A15: a widget-kind behavior needs NO green unit anchors — the '
      'view lane is contract-driven (the #830 dead-end with zero units '
      'is gone)', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: _widgetDescription,
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'A-100',
      description: _widgetDescription,
      subjectContent: '''
library;

/// View-builder subject for behavior A-100.
Widget subject_a_100() => throw UnimplementedError('subject_a_100 not implemented');
''',
      testContent: widgetTargetTest(_widgetDescription),
    );
    final zfaBin = await fx.writeFakeZfaBin(
      logPath: fx.fakeZfaLogPath,
      sideEffectByArgv: {
        'tdd view': fx.overwriteSubjectCommands('A-100', _implementedView),
      },
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(
      makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
    );

    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('make: behavior=A-100 outcome=green feature=${fx.featureName}'),
    );
  });

  test('A16: the pre-#939 shape is gone — a widget-kind make NEVER '
      'mislabels the row as unit-kind', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: _widgetDescription,
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'A-100',
      description: _widgetDescription,
      subjectContent: '''
library;

/// View-builder subject for behavior A-100.
Widget subject_a_100() => throw UnimplementedError('subject_a_100 not implemented');
''',
      testContent: widgetTargetTest(_widgetDescription),
    );
    // The fake view step does NOT implement the subject — the make must
    // fail honestly (generation-error via the failing target test), but
    // the OLD mislabel ("is unit-kind") must never appear, and the OLD
    // outcome (unexpressible at the planning stage) is gone: the plan
    // runs the widget lane's generation steps.
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(
      makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
    );

    expect(exitCode, isNot(0));
    expect(out, isNot(contains('is unit-kind')));
    expect(out, isNot(contains('outcome=unexpressible')));
    // The widget lane engaged and ran its generation step.
    expect(out, contains('widget lane: view-builder generation'));
    final log = await fx.readFakeZfaLog();
    expect(log, isNotEmpty);
    expect(log.first, contains('tdd view A-100'));
  });

  test('A17: unit-kind behaviors keep the honest pre-#939 stop (no '
      'regression on the acceptance-only composition gate)', () async {
    await fx.seedTestList([
      (
        id: 'U-100',
        description: 'a unit behavior with prose no planner maps',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'U-100',
      description: 'provision bespoke DSL syntax with no generator surface',
    );
    final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(
      makeArgs(fx, id: 'U-100', zfaBin: zfaBin),
    );

    expect(exitCode, isNot(0));
    expect(out, contains('outcome=unexpressible'));
    // The refusal names the ACTUAL kind now (accurate, still honest).
    expect(out, contains('is unit-kind'));
    // Pipeline NEVER invoked — misfire before any generation.
    final log = await fx.readFakeZfaLog();
    expect(log, isEmpty);
  });
}
