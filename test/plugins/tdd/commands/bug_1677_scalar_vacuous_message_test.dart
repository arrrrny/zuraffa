@Tags(['slow'])
// Issue #1677 — the scalar vacuous-green refusal prints the void/entity
// explanation (driver level).
//
// The #1651 scalar type-only shape's generated test CARRIES the
// `zfa:tdd: vacuous-guard` marker, so the run driver's make
// vacuous-green marker-present arm fires — and prints the #1308
// void/entity template: "the traced contract's return is void/an entity
// — ... the assertion set is the UnimplementedError guard only". For a
// scalar contract (`add(int a, int b) -> int`) BOTH claims are false:
// the return is neither void nor an entity, and the assertion set is
// the declared-return-TYPE check the #1517 func dummy satisfies — the
// make refusal excerpt above the paragraph on the same screen says
// exactly that (the issue #1651 placeholder wording). The two
// paragraphs contradict each other on the same screen.
//
// The remedy: the refusal message discriminates the branch the
// writer's emission already discriminates (`behavior_test_writer.dart`
// `_declaredAssertion` — the scalar branch emits the marker WITH the
// typed type-only assertion). Scalar-declared contracts get the #1651
// scalar explanation; void/entity contracts keep the #1308
// hand-delta-seam explanation. The machine contract
// (`stopped_at=<id>:hand`) and the `hand step:` line are UNCHANGED —
// messaging only.
//
// Mirrors issue_1308_vacuous_guard_remedy_driver_test.dart's harness:
// the REAL RunDriverCore over a scripted fake zfa binary.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The #1651 scalar type-only generated shape the writer emits for a
/// scalar-declared contract with no scenario value: the capture, the
/// marker comment ([typeOnlyVacuousGuardComment]'s text), and the typed
/// type-only assertion.
String scalarTypeOnlyTest(String feature) => '''
// GENERATED TEST — `zfa tdd gen U1`.
library;

import 'package:test/test.dart';

void main() {
  test('U1 — adds two integers', () {
    final result = (() {
      try {
        return subject.subjectU1(0, 0);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    // zfa:tdd: vacuous-guard (issue #1651): the assertion below checks the
    // declared return TYPE only — a func-scaffolded dummy (`return 0;`)
    // satisfies it, so a green here proves nothing about the outcome
    // value. Replace it with an assertion on the observable outcome
    // named by the behavior description (the spec's scenario values),
    // remove this marker, and re-run make.
    expect(result, isA<int>());
  });
}
''';

/// The review-of-#1701 hand-authored shape: the marker block with THREE
/// type-only expects over different subjects — `isA<int>()`,
/// `isA<String>()`, then `isA<int>()` again. The plural extraction must
/// name BOTH distinct types in first-occurrence order
/// (`scalar (int, String)`) with the duplicate collapsed (U3).
String scalarMultiTypeOnlyTest(String feature) => '''
// GENERATED TEST — `zfa tdd gen U1`.
library;

import 'package:test/test.dart';

void main() {
  test('U1 — adds two integers', () {
    final result = (() {
      try {
        return subject.subjectU1(0, 0);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    final name = (() {
      try {
        return subject.subjectU2();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    // zfa:tdd: vacuous-guard (issue #1651): the assertions below check the
    // declared return TYPE only — a func-scaffolded dummy (`return 0;`)
    // satisfies them, so a green here proves nothing about the outcome
    // value. Replace them with assertions on the observable outcome
    // named by the behavior description (the spec's scenario values),
    // remove this marker, and re-run make.
    expect(result, isA<int>());
    expect(name, isA<String>());
    expect(result, isA<int>());
  });
}
''';

/// The #1259 entity/void generated shape: the capture, the marker
/// comment ([vacuousGuardComment]'s text), and the bare
/// UnimplementedError guard.
String guardOnlyTest(String feature) => '''
// GENERATED TEST — `zfa tdd gen U1`.
library;

import 'package:test/test.dart';

void main() {
  test('U1 — creates the user entity', () {
    final result = (() {
      try {
        return subject.subjectU1();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    // zfa:tdd: vacuous-guard (issue #1259): the assertion set below is the
    // UnimplementedError guard ONLY — a green here proves nothing about
    // the behavior (a dummy `return 0;` flips it green with zero
    // declared-contract code). Replace this guard with an assertion on
    // the observable outcome named by the behavior description, remove
    // this marker, and re-run make.
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';

void main() {
  group('bug 1677 — the make vacuous-green marker-present refusal '
      'message (driver level)', () {
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
# Fake zfa CLI for the #1677 driver test.
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

    /// Seeds the traced scalar contract row (`add(int a, int b) -> int`,
    /// the issue's U1 shape), the generated test at the #827 namespaced
    /// layout, and the make vacuous-green outcome, then drives the run.
    /// [testContent] is the generated test body (U1's scalar emission,
    /// U3's multi-expect variant, …).
    Future<String> driveScalarFeature(
      String feature,
      String testContent,
    ) async {
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      final testPath = p.join(
        fx.root.path,
        'test',
        'tdd',
        feature,
        'u1_test.dart',
      );
      await File(
        testPath,
      ).create(recursive: true).then((file) => file.writeAsString(testContent));
      expect(
        File(testPath).readAsStringSync(),
        contains('zfa:tdd: vacuous-guard'),
      );
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'adds two integers via Calculator.add',
          traces: 'FR-001, Calculator',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

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

    test('U1: a scalar contract\'s vacuous-green refusal prints the '
        '#1651 scalar explanation — never the void/entity template', () async {
      final out = await driveScalarFeature(
        '1677-scalar-message',
        scalarTypeOnlyTest('1677-scalar-message'),
      );

      // The honest stop and the UNCHANGED machine contract (issue #1308
      // semantics: marker present → the named hand step).
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:hand'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:make')), reason: out);

      // THE FIX: the scalar branch explanation (issue #1651) — the
      // declared return TYPE check the func dummy satisfies.
      expect(
        out,
        contains("the traced contract's return is scalar (int)"),
        reason: out,
      );
      expect(
        out,
        contains('checks the declared return TYPE only'),
        reason: out,
      );
      expect(out, contains('(issue #1651)'), reason: out);

      // The #1308 void/entity template is FALSE here — the return is
      // neither void nor an entity, and the assertion set is NOT the
      // UnimplementedError guard only.
      expect(
        out,
        isNot(contains("the traced contract's return is void/an entity")),
        reason: out,
      );
      expect(
        out,
        isNot(
          contains('the assertion set is the UnimplementedError guard only'),
        ),
        reason: out,
      );

      // The `hand step:` line is UNCHANGED (the constraint).
      expect(out, contains('hand step: U1:hand'), reason: out);
      expect(out, contains('assertion on the observable outcome'), reason: out);
    });

    test('U3: two type-only expects over different scalars — the refusal '
        'names BOTH distinct types, duplicate collapsed '
        '(review-of-#1701 plural pin)', () async {
      final out = await driveScalarFeature(
        '1677-multi-scalar-message',
        scalarMultiTypeOnlyTest('1677-multi-scalar-message'),
      );

      // The machine contract is UNCHANGED.
      expect(out, contains('stopped_at=U1:hand'), reason: out);

      // THE PLURAL PIN: the paragraph names every DISTINCT type the
      // content's type-only expects check, first-occurrence order — not
      // just the first matcher's type.
      expect(
        out,
        contains("the traced contract's return is scalar (int, String)"),
        reason: out,
      );
      // The void/entity template is still FALSE for a scalar shape.
      expect(
        out,
        isNot(contains("the traced contract's return is void/an entity")),
        reason: out,
      );
      // The `hand step:` line is UNCHANGED (the constraint).
      expect(out, contains('hand step: U1:hand'), reason: out);
    });

    test('U2: a void/entity contract\'s vacuous-green refusal keeps the '
        '#1308 hand-delta-seam explanation (guard pin)', () async {
      const feature = '1677-void-message-guard';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      final testPath = p.join(
        fx.root.path,
        'test',
        'tdd',
        feature,
        'u1_test.dart',
      );
      await File(testPath)
          .create(recursive: true)
          .then((file) => file.writeAsString(guardOnlyTest(feature)));
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'creates the user entity',
          traces: 'FR-001, UserRepo',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
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

      // The #1308 explanation STANDS for the void/entity branch.
      expect(out, contains('stopped_at=U1:hand'), reason: out);
      expect(
        out,
        contains("the traced contract's return is void/an entity"),
        reason: out,
      );
      expect(out, contains('the designed hand-delta seam'), reason: out);
      expect(out, contains('(issue #1308)'), reason: out);

      // The scalar template is FALSE here — a void/entity contract has
      // no declared scalar return type to name.
      expect(
        out,
        isNot(contains("the traced contract's return is scalar")),
        reason: out,
      );
      // The `hand step:` line is UNCHANGED (the constraint).
      expect(out, contains('hand step: U1:hand'), reason: out);
    });
  });
}
