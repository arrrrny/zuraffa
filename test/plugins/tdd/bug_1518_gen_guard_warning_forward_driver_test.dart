// Bug #1518 — the run transcript must carry TWO AGREEING `--> fix:` lines.
//
// The issue's exact scenario, inverted into the acceptance proof: in ONE
// `zfa tdd run` over a LEGACY single-file feature, the gen child's
// forwarded guard-only warning printed the pre-#1483 advice (a bare
// `04-ENGINE.md` that does not exist for this shape) while the later
// vacuous-green make stop printed the branched advice (the test-list
// traces cell) — wrong remedy first, right remedy second, two
// contradictory `--> fix:` lines in one transcript. Post-#1518 both lines
// resolve the seam from disk: the gen warning and the stop agree.
//
// Driver-level over the scripted fake zfa binary (the issue #1308/#1483
// driver-suite convention): the fake gen prints the writer's branched
// warning shape and exits 0; the fake make refuses vacuous-green.
//
// Test map:
//   U-1518-7 (driver) — a legacy single-file feature's run transcript
//            carries the forwarded gen warning AND the vacuous-green stop
//            with two agreeing `--> fix:` lines (both name
//            `specs/<feature>/tdd/test-list.md`; neither names
//            04-ENGINE); `stopped_at=U1:make` preserved.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1518 — the run transcript carries agreeing remedies (driver)', () {
    late TddFixture fx;

    /// The scripted fake zfa binary: gen prints the writer's BRANCHED
    /// warning shape (token line + the `--> fix:` line, the two-line shape
    /// the real writer emits) and exits 0; verify-red certifies red; make
    /// refuses vacuous-green.
    Future<void> writeBug1518FakeZfa(String feature) async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = p.join(fx.fakeZfaDir, 'config');
      await Directory(configDir).create(recursive: true);
      final logPath = p.join(fx.fakeZfaDir, 'log');
      await File(logPath).writeAsString('');
      const script = r'''#!/bin/sh
# Fake zfa CLI for the #1518 driver test.
echo "$@" >> "__ARGVLOG__"
STEP="$2"
ID="$3"
CYCLE="__PROJECT__/specs/__FEATURE__/tdd/cycle-log.md"
case "$STEP" in
  gen)
    echo "zfa tdd gen: WARNING [zfa:tdd: guard-only] behavior \"$ID\" — the generated unit test's only assertion is the bare UnimplementedError guard: no traces: line derives a real outcome assertion (issue #1259, #1308)."
    echo "   --> fix: __REMEDY__"
    exit 0 ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-09-01T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=__FEATURE__"
    exit 0
    ;;
  make)
    echo "make: behavior=$ID outcome=vacuous-green feature=__FEATURE__"
    exit 1 ;;
  *)
    echo "zfa tdd $STEP: unknown step"
    exit 1
    ;;
esac
''';
      // The branched remedy the REAL writer prints over the single-file
      // shape (the test-list seam, full project-relative path) — the same
      // `vacuousGuardFallbackRemedyFor` wording the fake's gen echoes.
      final remedy =
          'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
          're-run zfa tdd gen, re-run zfa tdd run — or hand-edit the '
          'test list (${p.join('specs', feature, 'tdd', 'test-list.md')}) '
          'traces cell to FR-00N, Row.method and re-run zfa tdd gen '
          '(the designed hand-delta seam)';
      final bin = File(fx.fakeZfaBin);
      await bin.writeAsString(
        script
            .replaceAll('__ARGVLOG__', fx.fakeZfaArgvLogPath)
            .replaceAll('__PROJECT__', fx.root.path)
            .replaceAll('__FEATURE__', feature)
            .replaceAll('__REMEDY__', remedy),
      );
      Process.runSync('chmod', ['+x', fx.fakeZfaBin]);
    }

    test('U-1518-7: the forwarded gen warning and the vacuous-green stop name '
        'the SAME seam — no contradictory --> fix: lines', () async {
      const feature = '1518-agreeing-remedies';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeBug1518FakeZfa(feature);
      // The legacy single-file shape: NO lane plan pair on disk — both
      // remedy lines must name the test list.
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'lets the user add a todo with a title',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      expect(
        File(p.join(fx.featureDir, 'tdd', '04-ENGINE.md')).existsSync(),
        isFalse,
      );

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

      // The honest stop is unchanged: the fallback vacuous-green arm,
      // the make step machine contract preserved (no behavior change).
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);

      // THE FIX: both `--> fix:` lines in the transcript — the forwarded
      // gen warning's and the stop's — name the SAME test-list seam.
      final fixLines = out
          .split('\n')
          .where((l) => l.contains('--> fix:'))
          .toList();
      expect(fixLines, hasLength(2), reason: out);
      for (final line in fixLines) {
        expect(
          line,
          contains(
            'hand-edit the test list '
            '(${p.join('specs', feature, 'tdd', 'test-list.md')}) '
            'traces cell',
          ),
          reason: out,
        );
        expect(line, isNot(contains('04-ENGINE')), reason: out);
      }
      // The warning token reached the transcript (the forward works).
      expect(out, contains('zfa:tdd: guard-only'), reason: out);
    });
  });
}
