// Bug #1420 (driver) — the vacuous-green stop for a DECLARED-trace row never
// claims "no traces".
//
// The marker-absent vacuous-green make stop used to print "fallback-routed
// (no traces: to a declared contract row)" and prescribe
// `add traces: <ContractRow>` — FALSE when the traces cell resolves a
// declared Key Entity row (the trace exists) and IMPOSSIBLE to follow (entity
// rows declare no methods to qualify). The stop now probes the declared
// routing (the same single-sourced `DeclaredRouting.declaredRoutingFor` gen
// resolves through) and, when declared row(s) resolve, names the declared
// class and the stale-artifact re-gen remedy.
//
// Messaging only: the detection, the stop result and the
// `stopped_at=<id>:make` machine contract, and the loop semantics are
// untouched (the #1483 driver-suite conventions).
//
// Test map (slow tier — the real RunDriverCore over a scripted fake zfa):
//   U-1420-R1 — a unit row whose traces cell resolves a declared entity row:
//               the stop names the declared entity row + re-gen remedy, never
//               "no traces"; `stopped_at=U1:make` preserved.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1420 — the vacuous-green stop for a declared-trace row', () {
    late TddFixture fx;

    /// The scripted fake zfa binary (the issue #1308 shape): gen is silent,
    /// verify-red certifies red, make refuses vacuous-green.
    Future<void> writeFakeZfa() async {
      await Directory(fx.fakeZfaDir).create(recursive: true);
      final configDir = p.join(fx.fakeZfaDir, 'config');
      await Directory(configDir).create(recursive: true);
      final logPath = p.join(fx.fakeZfaDir, 'log');
      await File(logPath).writeAsString('');
      const script = r'''#!/bin/sh
# Fake zfa CLI for the #1420 driver test.
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

    test('U-1420-R1: a declared entity-row trace stops with the accurate '
        'message + re-gen remedy, never "no traces"', () async {
      const feature = '1420-declared-trace-stop';
      const entityName = 'SharedAttachmentType';
      fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);
      await writeFakeZfa();
      await File(
        p.join(fx.fakeZfaDir, 'config', 'make-U1'),
      ).writeAsString('vacuous-green');

      // The DECLARED-trace shape: the traces cell resolves a declared Key
      // Entity row (row-only — the issue's class), the spec declares it.
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'exposes exactly the four share attachment kinds',
          traces: 'FR-001, $entityName',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(fx.featureDir).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
# Spec: $feature

## Functional Requirements

- **FR-001**: `$entityName` MUST expose exactly the four share attachment kinds

### Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| $entityName | `kind: String` | the four share attachment kinds |
''');

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

      // The stop is the honest fallback class, machine contract preserved.
      expect(
        out,
        contains('behavior=U1 step=make outcome=vacuous-green'),
        reason: out,
      );
      expect(out, contains('stopped_at=U1:make'), reason: out);
      expect(out, isNot(contains('stopped_at=U1:hand')), reason: out);

      // THE FIX: the declared class is named — the false "no traces" claim
      // and the impossible "add traces" remedy are gone.
      expect(
        out,
        isNot(contains('no traces: to a declared contract row')),
        reason: out,
      );
      final fixLine = out
          .split('\n')
          .firstWhere((l) => l.contains('--> fix:'), orElse: () => '');
      expect(fixLine, isNot(contains('add traces:')), reason: out);
      expect(fixLine, contains('zfa tdd gen U1'), reason: out);
      expect(out, contains(entityName), reason: out);
    });
  });
}
