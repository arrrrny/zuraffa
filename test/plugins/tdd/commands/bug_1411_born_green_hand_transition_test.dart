@Tags(['slow'])
// Issue #1411 — the hand-first born-green catch-22. The designed
// hand-step flow (guide §5a item 1, issues #1259/#1308) prescribes:
// replace the vacuous-guard test with real assertions, hand-implement
// the subject, re-run `zfa tdd run`. When the hand step is completed
// BEFORE the pipeline's first pass, no red evidence exists in
// cycle-log.md: verify-red sees the already-passing test →
// unexpected-green → skipped; make refuses not-certified-red; the run
// stops with no recovery path.
//
// Fix under test (spec 1411-hand-first-born-green-transition):
//   make block (real `dart test` runner):
//     B1 — `make <id> --born-green` with the full gate shape (passing
//          test, marker absent, U<n>:hand header present, no red
//          evidence) → exit 0, outcome=born-green, green evidence in
//          the existing format.
//     B2 — no flag + attested shape → the not-certified-red refusal
//          OFFERS the exact `--born-green` command.
//     B3 — flag + marker present → vacuous-green safe-failure.
//     B4 — flag + header absent → not-certified-red naming the exact
//          header line.
//     B5 — flag + failing test → not-certified-red naming verify-red.
//     B6 — certified red + flag → the #694 skip transition (flag
//          inert; backward compat).
//     B7 — flag + passing test against a PLACEHOLDER subject →
//          vacuous-green refusal (the #1036 class).
//   driver block (scripted fake zfa):
//     D1 — attested catch-22 through `zfa tdd run` → the hand-off
//          names `--born-green`, stops at <id>:hand, journal carries
//          the #1411 hand-step violation.
//     D2 — un-attested → the exact header line is named.
//     D3 — red-first-shaped refusal (verify-red certified, make
//          refuses) → the generic stop stands (no hand-off).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The attestation header line the designed hand step adds (the exact
/// string the messages must name).
String handHeader(String id) =>
    '// zfa:tdd: $id:hand — hand step completed before first red '
    'certification (issue #1411)';

/// A passing hand-completed unit test (real outcome assertion, marker
/// removed) carrying the attestation header when [attested].
String bornGreenTest(String description, {required bool attested}) => '''
${attested ? handHeader('U1') : '// hand-completed test'}
import '../lib/u1_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(u1_value(), equals(42));
  });
}
''';

/// A type-only assertion test that PASSES against a vacuous scaffold
/// subject (`int u1_value() => 0;`) — the #1036 born-green vacuity.
String typeOnlyTest(String description, {required bool attested}) => '''
${attested ? handHeader('U1') : ''}
import '../lib/u1_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(u1_value(), isA<int>());
  });
}
''';

/// The guard-only generated shape with the vacuous-guard marker still
/// present (the hand step's test side not yet done) — the subject is
/// implemented, so the guard passes.
String guardOnlyTest(String description) => '''
// GENERATED TEST — `zfa tdd gen U1`.
${handHeader('U1')}
import '../lib/u1_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    // zfa:tdd: vacuous-guard (issue #1259): the assertion set below is
    // the UnimplementedError guard ONLY.
    expect(u1_value(), isNot(isA<UnimplementedError>()));
  });
}
''';

const _description = 'the counter exposes the total';

void main() {
  group('make block (real runner)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create();
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    Future<String> drive(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing(args);
    }

    List<String> bornGreenArgs({String? id = 'U1'}) => [
      'tdd',
      'make',
      '--project',
      fx.root.path,
      '--born-green',
      ?id,
    ];

    test(
      'B1 (issue #1411): born-green hand transition — full gate → exit 0, '
      'outcome=born-green, green evidence in the existing format',
      () async {
        // The hand-first state: NO red evidence, a PASSING
        // hand-completed test (marker absent), the attestation header,
        // a hand-implemented subject.
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent: bornGreenTest(_description, attested: true),
        );
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 42;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=born-green'), reason: out);
        expect(out, contains('born-green hand transition'), reason: out);
        // The evidence is real and in the existing format: a green
        // entry with the `- evidence:` note, the explicitly empty
        // generation block, and the honest zero suite numbers.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('## Cycle: U1 (green)'));
        expect(cycleLog, contains('- evidence:'));
        expect(cycleLog, contains('issue #1411 born-green hand transition'));
        expect(cycleLog, contains('- generation:'));
        expect(cycleLog, contains('  (none)'));
        expect(cycleLog, contains('- suite: baseline=0 guard=0'));
      },
    );

    test(
      'B2: no flag + attested shape → the refusal OFFERS the exact '
      '--born-green command',
      () async {
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent: bornGreenTest(_description, attested: true),
        );
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 42;\n');

        final out = await drive([
          'tdd',
          'make',
          '--project',
          fx.root.path,
          'U1',
        ]);

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('no certified-red evidence'), reason: out);
        expect(out, contains('outcome=not-certified-red'), reason: out);
        expect(out, contains('--born-green'), reason: out);
        expect(out, contains('zfa tdd make U1 --born-green'), reason: out);
      },
    );

    test(
      'B3: flag + vacuous-guard marker still present → vacuous-green '
      'safe-failure naming the completion remedy',
      () async {
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent: guardOnlyTest(_description),
        );
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 42;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=vacuous-green'), reason: out);
        expect(out, contains('zfa:tdd: vacuous-guard'), reason: out);
        expect(out, contains('--born-green'), reason: out);
        // No green evidence was appended.
        expect(
          await File(fx.cycleLogPath).exists(),
          isFalse,
          reason: 'a refused transition appends no green entry',
        );
      },
    );

    test(
      'B4: flag + header absent → not-certified-red naming the exact '
      'header line',
      () async {
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent: bornGreenTest(_description, attested: false),
        );
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 42;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=not-certified-red'), reason: out);
        expect(out, contains(handHeader('U1')), reason: out);
      },
    );

    test(
      'B5: flag + FAILING target test → not-certified-red naming '
      'verify-red (the honest red-first remedy)',
      () async {
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent:
              '''
${handHeader('U1')}
import '../lib/u1_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$_description', () {
    expect(u1_value(), equals(42));
  });
}
''',
        );
        // The subject is still the wrong-value stub: the test fails.
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 0;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=not-certified-red'), reason: out);
        expect(out, contains('zfa tdd verify-red U1'), reason: out);
      },
    );

    test(
      'B6 (backward compat): certified red + flag → the #694 skip '
      'transition stands (the flag is inert in the red-first ordering)',
      () async {
        await fx.seedCertifiedRed(
          id: 'U1',
          description: _description,
          testContent: bornGreenTest(_description, attested: true),
        );
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 42;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, 0, reason: out);
        expect(out, contains('outcome=skipped'), reason: out);
        expect(out, isNot(contains('outcome=born-green')), reason: out);
      },
    );

    test(
      'B7: flag + passing test against a PLACEHOLDER subject → '
      'vacuous-green refusal (the #1036 born-green vacuity class)',
      () async {
        await fx.registerBehavior(
          id: 'U1',
          description: _description,
          testContent: typeOnlyTest(_description, attested: true),
        );
        // The vacuous func-scaffold literal: the type-only test passes
        // against it, but nothing is implemented.
        await File(
          fx.subjectPathOf('U1'),
        ).writeAsString('int u1_value() => 0;\n');

        final out = await drive(bornGreenArgs());

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=vacuous-green'), reason: out);
        expect(out, contains('PLACEHOLDER'), reason: out);
      },
    );
  });

  group('driver block (fake zfa)', () {
    late TddFixture fx;

    /// The scripted fake zfa binary: gen ok; verify-red grades
    /// unexpected-green (the passing-test signature, no red evidence);
    /// make refuses not-certified-red. [certifyRed] flips verify-red
    /// into the certified shape (D3's red-first ordering simulation)
    /// with the fake appending the red evidence entry itself.
    Future<void> writeFakeZfa({required bool certifyRed}) async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = Directory(p.join(fx.fakeZfaDir, 'config'))
        ..create(recursive: true);
      await File(p.join(fx.fakeZfaDir, 'log')).writeAsString('');
      final classify = certifyRed
          ? 'certified=true classification=assertionFailure'
          : 'classification=unexpected-green';
      final redAppend = certifyRed
          ?
            '''
    CYCLE="\$PROJECT/specs/\$FEATURE/tdd/cycle-log.md"
    mkdir -p "\$PROJECT/specs/\$FEATURE/tdd"
    printf '\\n## Cycle: %s (red)\\n\\n- behavior: %s\\n- kind: red\\n- classification: assertionFailure\\n- criterion: FR-001\\n- test: test/tdd/%s/u1_test.dart\\n- command: `fake`\\n- exit: 1\\n- at: 2026-09-11T00:00:00.000Z\\n- output:\\n```\\nExpected: <2>\\n```\\n\\n' "\$ID" "\$ID" "\$FEATURE" >> "\$CYCLE"
'''
          : '';
      final script = '''
#!/bin/sh
echo "\$@" >> "__ARGVLOG__"
STEP="\$2"
ID="\$3"
HEAD="\$1"
FEATURE=""
PROJECT=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    --feature) FEATURE="\$2"; shift ;;
    --project) PROJECT="\$2"; shift ;;
  esac
  shift
done
if [ "\$HEAD" != "tdd" ]; then
  exit 0
fi
echo "\$STEP \$ID" >> "__LOG__"
CFG="__CFG__/\$STEP-\$ID"
if [ -f "\$CFG" ]; then
  OUTCOME=\$(cat "\$CFG")
else
  OUTCOME="ok"
fi
case "\$STEP" in
  gen)
    exit 0 ;;
  verify-red)
    echo "verify-red: behavior=\$ID $classify feature=\$FEATURE"
$redAppend    exit 0 ;;
  make)
    echo "make: behavior=\$ID outcome=not-certified-red feature=\$FEATURE"
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

    /// Seed the generated-test-shaped file at the canonical driver path.
    Future<void> seedGeneratedTest(
      String feature,
      String content,
    ) async {
      final testPath = p.join(
        fx.root.path,
        'test',
        'tdd',
        feature,
        'u1_test.dart',
      );
      await File(testPath).parent.create(recursive: true);
      await File(testPath).writeAsString(content);
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
      'D1 (issue #1411): the attested hand-first catch-22 stops at the '
      'named hand step with the exact --born-green recovery',
      () async {
        const feature = '1411-born-green';
        fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        await writeFakeZfa(certifyRed: false);
        await fx.seedTestList([
          (
            id: 'U1',
            description: _description,
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await seedGeneratedTest(
          feature,
          bornGreenTest(_description, attested: true),
        );

        final out = await drive(feature);

        expect(
          out,
          contains('behavior=U1 step=make outcome=not-certified-red'),
          reason: out,
        );
        expect(out, contains('hand step: U1:hand'), reason: out);
        expect(
          out,
          contains('zfa tdd make U1 --born-green'),
          reason: out,
        );
        expect(out, contains('stopped_at=U1:hand'), reason: out);

        // The journal carries the #1411 hand-step vocabulary.
        final journalPath = p.join(fx.featureDir, 'tdd', 'journal.json');
        final decoded =
            jsonDecode(File(journalPath).readAsStringSync())
                as Map<String, dynamic>;
        final entries =
            (decoded['entries'] as List).cast<Map<String, dynamic>>();
        final entry = entries.lastWhere(
          (e) => e['cycle'] == 'engine' && e['phase'] == 'drive',
        );
        expect(entry['stopped_at'], 'U1:hand');
        final violations = (entry['violations'] as List)
            .cast<String>()
            .join('\n');
        expect(violations, contains('hand-step=U1:hand'));
        expect(violations, contains('--born-green'));
      },
    );

    test(
      'D2: the un-attested hand-first state names the exact header line',
      () async {
        const feature = '1411-unattested';
        fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        await writeFakeZfa(certifyRed: false);
        await fx.seedTestList([
          (
            id: 'U1',
            description: _description,
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await seedGeneratedTest(
          feature,
          bornGreenTest(_description, attested: false),
        );

        final out = await drive(feature);

        expect(out, contains('hand step: U1:hand'), reason: out);
        expect(out, contains(handHeader('U1')), reason: out);
        expect(
          out,
          contains('zfa tdd make U1 --born-green'),
          reason: out,
        );
        expect(out, contains('stopped_at=U1:hand'), reason: out);
      },
    );

    test(
      'D3 (backward compat): a red-first-shaped refusal keeps the '
      'generic stop — no hand-off without the catch-22 signature',
      () async {
        const feature = '1411-red-first';
        fx = await TddFixture.create(featureName: feature);
        addTearDown(fx.dispose);
        // verify-red CERTIFIES red (the fake appends the evidence) and
        // make still refuses — an in-order red-first drive never
        // carries the unexpected-green signature, so the generic stop
        // must stand.
        await writeFakeZfa(certifyRed: true);
        await fx.seedTestList([
          (
            id: 'U1',
            description: _description,
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await seedGeneratedTest(
          feature,
          bornGreenTest(_description, attested: true),
        );

        final out = await drive(feature);

        expect(
          out,
          contains('behavior=U1 step=make outcome=not-certified-red'),
          reason: out,
        );
        expect(out, contains('stopped_at=U1:make'), reason: out);
        expect(out, contains('resume: fix the failing step'), reason: out);
        expect(out, isNot(contains('hand step: U1:hand')), reason: out);
      },
    );
  });
}
