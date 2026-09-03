@Tags(['slow'])
// Make-level test for the widget/func-verb routing bug (issue #950): a
// widget-kind behavior whose description carries the func verb "renders"
// used to route the primary generation plan to `tdd func` (branch 3,
// functionIntentVerbs) — whose scaffold refuses the gen-shaped
// view-builder stub, dead-ending the make in a generation-error — while
// the #939 view lane sat unreachable in the composition fallback. The
// planner now plans widget-kind rows unexpressible (the #835 principle:
// kind outranks prose), so the fallback's view-builder lane engages and
// the make reaches green through `tdd view <id>` + `build`, never
// `tdd func`.
//
// Drives the public CLI surface (`zfa tdd make`) against a TddFixture
// whose registry carries a widget-kind behavior with the gen-shaped
// view-builder stub SubjectWriter emits (bug #830) — the SAME shape the
// issue's real-CLI repro refuses. Mirrors make_command_widget_939_test
// .dart, whose descriptions deliberately carry no func verb (the gap
// this issue pins).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd make` (mirrors the #939 helper).
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

/// THE collision prose: the single most natural widget-scenario verb,
/// present tense per the UI-intent contract (the issue's exact scenario
/// literal).
const _widgetDescription = "the widget renders 'Hello, shopper'";

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
/// widget test applies (issue #830 taxonomy) in pure-Dart fixture form.
String widgetTargetTest(String description) =>
    '''
import 'package:test/test.dart';

import '../lib/a_100_subject.dart' as subject;

void main() {
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

  test('W-A1: a widget-kind make whose description says "renders" reaches '
      'green through the view-builder lane — tdd view dispatched, never '
      'tdd func, exit 0', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: _widgetDescription,
        traces: 'FR-950',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'A-100',
      description: _widgetDescription,
      // The gen-shaped view-builder stub SubjectWriter emits for the
      // widget kind (bug #830) — the exact shape `tdd func` refuses in
      // the issue's repro.
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

    // Green certified, exit 0 — the func-verb prose no longer dead-ends
    // the widget lane.
    expect(exitCode, 0, reason: out);
    expect(
      out,
      contains('make: behavior=A-100 outcome=green feature=${fx.featureName}'),
    );
    // The routing is the view lane, never the func surface: the widget
    // lane is named and the dispatched steps are tdd view then build.
    expect(out, contains('widget lane: view-builder generation'));
    final log = await fx.readFakeZfaLog();
    expect(log, hasLength(2), reason: log.join('\n'));
    expect(log[0], contains('tdd view A-100'));
    expect(log[0], contains('--feature'));
    expect(log[1], 'build');
    expect(
      log.join('\n'),
      isNot(contains('tdd func')),
      reason: 'a widget-kind row must never route to the func scaffold',
    );
    // The green evidence records the view-lane invocations (FR-010).
    final cycleLog = await File(fx.cycleLogPath).readAsString();
    expect(cycleLog, contains('## Cycle: A-100 (green)'));
    expect(cycleLog, contains('tdd view A-100'));
  });
}
