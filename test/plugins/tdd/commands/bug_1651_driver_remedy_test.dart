@Tags(['slow'])
// Issue #1651 — the run driver's vacuous-green stop names the
// placeholder remedy (driver level).
//
// When make refuses the placeholder green (`outcome=vacuous-green`), the
// pre-#1651 stop prints the GUARD-ONLY fallback vocabulary ("the
// generated test is GUARD-ONLY") — wrong for the dummy class: the test
// is NOT guard-only, it type-checks a scalar placeholder body. The stop
// machine contract is unchanged (`stopped_at=<id>:make`, issue #1308);
// only the remedy classifies the placeholder.
//
// Mirrors bug_1483_vacuous_green_remedy_driver_test.dart's harness: the
// REAL RunDriverCore over a scripted fake zfa binary, with the REAL
// registry/artifact state the driver's remedy check reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The type-only unit test the scalar dummy satisfies (the post-#1259
/// generated shape).
String typeOnlyTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id \u2014 $description', () {
    final result = (() {
      try {
        return subject.$symbol(0, 0);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isA<int>());
  });
}
''';
}

String scalarDummySubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol(int a, int b) {
  return 0;
}
''';
}

void main() {
  group('bug 1651 — the run driver stop message (driver level)', () {
    late TddFixture fx;

    /// The scripted fake zfa binary (the #1308 shape): gen is silent,
    /// verify-red certifies red, make refuses vacuous-green.
    Future<void> writeFakeZfa() async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = p.join(fx.fakeZfaDir, 'config');
      await Directory(configDir).create(recursive: true);
      final logPath = p.join(fx.fakeZfaDir, 'log');
      await File(logPath).writeAsString('');
      const script = r'''#!/bin/sh
# Fake zfa CLI for the #1651 driver test.
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
CYCLE="$PROJECT/specs/$FEATURE/tdd/cycle-log.md"
case "$STEP" in
  gen)
    case "$OUTCOME" in
      ok) exit 0 ;;
      *) echo "zfa tdd gen: $OUTCOME"; exit 1 ;;
    esac
    ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-09-01T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0
    ;;
  make)
    case "$OUTCOME" in
      ok)
        printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-09-01T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
        echo "make: behavior=$ID outcome=green feature=$FEATURE"
        exit 0 ;;
      vacuous-green)
        echo "make: behavior=$ID outcome=vacuous-green feature=$FEATURE"
        exit 1 ;;
      *) echo "make: behavior=$ID outcome=$OUTCOME feature=$FEATURE"; exit 1 ;;
    esac
    ;;
  refactor)
    echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"
    exit 0
    ;;
  *)
    echo "zfa tdd $STEP: unknown step"
    exit 1
    ;;
esac
''';
      final bin = File(fx.fakeZfaBin);
      await bin.writeAsString(
        script
            .replaceAll('__LOG__', logPath)
            .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
            .replaceAll('__CFG__', configDir),
      );
      Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
    }

    test('U5: the vacuous-green stop names the placeholder remedy — the '
        'machine contract (stopped_at=<id>:make) is preserved', () async {
      const feature = '1651-driver-remedy';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();

      const id = 'U1';
      const description = 'the engine adds two integers';
      await fx.seedTestList([
        (
          id: id,
          description: description,
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // The REAL artifact state the driver's remedy check reads: a
      // func-scaffolded dummy paired with the type-only test.
      await fx.registerBehavior(
        id: id,
        description: description,
        sourceCriterion: 'FR-001',
        testContent: typeOnlyTest(id, description),
      );
      final subjectPath = p.join(
        fx.root.path,
        'lib',
        '${id.toLowerCase().replaceAll('-', '_')}_subject.dart',
      );
      await File(subjectPath).parent.create(recursive: true);
      await File(subjectPath).writeAsString(scalarDummySubject(id));
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-$id'),
      ).writeAsString('vacuous-green');

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

      // The stop machine contract is unchanged (issue #1308).
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);
      // THE FIX: the remedy classifies the PLACEHOLDER — it names the
      // dummy subject and never claims the test is guard-only.
      expect(out, contains('placeholder'), reason: out);
      expect(out, contains('u1_subject.dart'), reason: out);
      expect(out, isNot(contains('GUARD-ONLY')), reason: out);
    });
  });
}
