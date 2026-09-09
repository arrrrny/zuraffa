@Tags(['slow'])
// Issue #1373 — a SKIN/widget behavior whose generated test carries the
// `zfa:tdd: scaffolded` marker (issue #912 defect 3) stops the meta-run
// with the cryptic `not-certified-red` resume hint: verify-red classifies
// the trivially-green placeholder as unexpected-green (no red evidence),
// make refuses not-certified-red, and nothing in the output names the
// sanctioned `--author --finders-file` hand-off (issue #1258).
//
// Fix under test (spec 1373-scaffolded-hand-off): when the make step
// fails not-certified-red AND the behavior's generated test carries the
// scaffolded marker, the run driver names the hand step
// (`stopped_at=<id>:hand`) and prints the exact author remedy — mirroring
// the #1308 vacuous-guard hand step. Without the marker, the generic
// make stop is unchanged.
//
// Behaviors:
//   B1 — marker present → the hand step: the author remedy lines
//        (`--author --finders-file`) and `stopped_at=<id>:hand`.
//   B2 — marker absent → the generic make stop (`stopped_at=<id>:make`)
//        with the generic resume hint (guard).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  /// The scripted fake zfa binary: gen ok; verify-red exits 0 WITHOUT
  /// appending red evidence (the unexpected-green skip shape); make
  /// refuses not-certified-red.
  Future<void> writeIssue1373FakeZfa() async {
    await Directory(fx.fakeZfaDir).create(recursive: true);
    final configDir = Directory(p.join(fx.fakeZfaDir, 'config'))
      ..create(recursive: true);
    final logPath = p.join(fx.fakeZfaDir, 'log');
    await File(logPath).writeAsString('');
    const script = r'''#!/bin/sh
echo "$@" >> "__ARGVLOG__"
STEP="$2"
ID="$3"
HEAD="$1"
FEATURE=""
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done
if [ "$HEAD" != "tdd" ]; then
  exit 0
fi
echo "$STEP $ID" >> "__LOG__"
CFG="__CFG__/$STEP-$ID"
if [ -f "$CFG" ]; then
  OUTCOME=$(cat "$CFG")
else
  OUTCOME="ok"
fi
case "$STEP" in
  gen)
    exit 0 ;;
  verify-red)
    # The unexpected-green skip: the scaffolded placeholder passes
    # trivially, so no red evidence is appended and the step exits 0.
    echo "verify-red: behavior=$ID classification=unexpected-green feature=$FEATURE"
    exit 0 ;;
  make)
    echo "make: behavior=$ID outcome=not-certified-red feature=$FEATURE"
    exit 1 ;;
  refactor)
    exit 0 ;;
  *)
    exit 0 ;;
esac
''';
    final bin = File(fx.fakeZfaBin);
    await bin.writeAsString(
      script
          .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
          .replaceAll('__CFG__', configDir.path),
    );
    Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
  }

  /// The scaffolded widget test: carries the `zfa:tdd: scaffolded`
  /// marker (issue #912 defect 3) at the #827 namespaced layout.
  Future<void> seedScaffoldedWidgetTest(String feature) async {
    final testPath = p.join(
      fx.root.path,
      'test',
      'tdd',
      feature,
      'w1_test.dart',
    );
    await File(testPath).parent.create(recursive: true);
    await File(testPath).writeAsString('''
// GENERATED TEST — \`zfa tdd gen W1\`.
//
// zfa:tdd: scaffolded — scaffolded widget placeholder (issue #912
// defect 3): author concrete scenario finders, then hand the file over.
''');
  }

  Future<String> drive(String feature) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fx.fakeZfaBin,
    ]);
  }

  test(
    'B1: a scaffolded widget test stops at the named author hand step',
    () async {
      const feature = '1373-hand-off';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeIssue1373FakeZfa();
      await fx.seedTestList([
        (
          id: 'W1',
          description: 'skin behavior declared in ## Lanes',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'widget',
        ),
      ]);
      await seedScaffoldedWidgetTest(feature);

      final out = await drive(feature);

      expect(
        out,
        contains('behavior=W1 step=make outcome=not-certified-red'),
        reason: out,
      );
      expect(out, contains('SCAFFOLDED widget test'), reason: out);
      expect(out, contains('hand step: W1:hand'), reason: out);
      expect(out, contains('--author --finders-file'), reason: out);
      expect(out, contains('stopped_at=W1:hand'), reason: out);
    },
  );

  test('B2: a not-certified-red make stop WITHOUT the marker keeps the '
      'generic stop', () async {
    const feature = '1373-generic';
    fx = await TddFixture.create(featureName: feature);
    addTearDown(fx.dispose);
    await writeIssue1373FakeZfa();
    await fx.seedTestList([
      (
        id: 'W1',
        description: 'skin behavior declared in ## Lanes',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    // No scaffolded marker anywhere.

    final out = await drive(feature);

    expect(out, contains('stopped_at=W1:make'), reason: out);
    expect(out, contains('resume: fix the failing step'), reason: out);
    expect(out, isNot(contains('SCAFFOLDED widget test')), reason: out);
  });
}
