@Tags(['e2e'])
// Spec 1529 driver-level tests — the make step killed at the run
// driver's deadline leaves an INSPECTABLE receipt (US1 / U8), the
// explicit budget that looks unsafe draws a LOUD warning (US2 / U13),
// and the scaled default is handed down as the ONE uniform deadline
// (US2 / FR-4..FR-6).
//
// Fast-ish tier: the fixture's suite spy sleeps 0.5s (U8 reaches it live
// and the 1.2s deadline kills the capture; U13 seeds the corpus cache so
// its warning never races that capture); the fake zfa's make step sleeps
// 30s and is killed at the 1.2s deadline. No `dart test` compiles.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';

import '../helpers/tdd_fixture.dart';

/// The suite spy the fixture's TDD profile points at.
String _suiteSpyOf(TddFixture fx) => p.join(fx.root.path, '.spies', 'suite');

void main() {
  late TddFixture fx;
  const feature = '090-run-driver';

  /// The spec-1529 fake zfa entrypoint (written by [_writeFakeZfa]).
  late String fakeZfa1529;

  setUp(() async {
    fx = await TddFixture.create(featureName: feature, writeProfile: false);
    fakeZfa1529 = p.join(fx.root.path, 'fake_bin_1529', 'zfa');
    // The suite spy SLEEPS 0.5s before printing the green transcript.
    // It is deliberately NOT relied on to complete: on a loaded machine
    // a cold `#!/bin/sh` spawn can itself outlast the 1.2s budget, so
    // U8's capture is expected to be killed (its receipt assertions do
    // not depend on the measurement surviving), and U13 seeds the corpus
    // cache with a recorded duration instead of racing this process.
    final spyDir = p.join(fx.root.path, '.spies');
    await Directory(spyDir).create(recursive: true);
    final suiteSpy = _suiteSpyOf(fx);
    await File(suiteSpy).writeAsString(
      '#!/bin/sh\nsleep 0.5\n'
      "cat <<'SPY_EOF'\n"
      '${TddFixture.greenSuiteTranscript}\n'
      'SPY_EOF\nexit 0\n',
    );
    await Process.run('chmod', ['+x', suiteSpy]);
    await fx.rewriteProfile(
      singleTemplate: 'dart test {file} --plain-name "{name}"',
      suiteTemplate: suiteSpy,
    );
    // One behavior, certified red on disk (the fake zfa's verify-red
    // "ok" also appends a red entry — this keeps the evidence check
    // satisfied for the reuse-resume shapes too).
    await fx.seedTestList([
      (
        id: 'B-001',
        description: 'first behavior',
        traces: 'FR-001',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(id: 'B-001');
    await _writeFakeZfa(fx);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('U8: a make step killed at the deadline writes the timeout receipt '
      'and names it in the failure report', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fakeZfa1529,
      // 0.02 minutes = 1.2s — the make child (sleep 30) is killed.
      '--timeout',
      '0.02',
    ]);

    expect(exitCode, 2, reason: out);
    expect(out, contains('result=runner-error'));
    expect(out, contains('stopped_at=B-001:make'));
    // The failure report names the receipt (FR-1).
    expect(out, contains('timeout receipt:'));

    final receiptPath = p.join(fx.featureDir, 'tdd', 'make.B-001.timeout.json');
    expect(
      File(receiptPath).existsSync(),
      isTrue,
      reason:
          'the receipt lands in the feature tdd dir (the issue glob '
          'make.u8.*.json shape)',
    );
    final receipt =
        jsonDecode(File(receiptPath).readAsStringSync())
            as Map<String, dynamic>;
    expect(receipt['schema'], 'tdd-make-timeout-receipt.v1');
    expect(receipt['behavior'], 'B-001');
    expect(receipt['step'], 'make');
    final argv = (receipt['argv'] as List).join(' ');
    expect(argv, contains('make'));
    expect(argv, contains('--timeout 0.0200'));
    // The child slept 30s; the kill landed at the 1.2s deadline.
    final elapsedMs = receipt['elapsed_ms'] as int;
    expect(elapsedMs, greaterThanOrEqualTo(1000));
    expect(elapsedMs, lessThan(25000));
    expect(receipt['deadline_ms'], 1200);
    // The fake's make step prints nothing and spawns only `sleep` —
    // the honest `unknown` phase (FR-3: never a silent guess).
    expect(receipt['phase'], 'unknown');
    expect(receipt['phase_evidence'], isA<String>());
    // No green evidence may exist for the killed make.
    final log = File(fx.cycleLogPath).readAsStringSync();
    expect(log, isNot(contains('- kind: green\n- behavior: B-001')));
  });

  test('U13: an explicit --timeout below the projected make cost draws the '
      'loud warning before the first step spawns', () async {
    // Seed the corpus baseline cache with a recorded 5s capture instead
    // of measuring the 0.5s spy live. The live variant raced the very
    // budget under test: a cold spawn on a loaded machine outlasts the
    // 1.2s deadline, the capture is killed, no baseline is measured, and
    // the warning this test exists to pin never prints. A reused cache
    // substitutes its recorded duration (US2.3), so 4 x 5s = 20s >= 1.2s
    // is deterministic.
    await _seedCorpusBaseline(fx, durationMs: 5000);
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fakeZfa1529,
      '--timeout',
      '0.02',
    ]);

    expect(exitCode, 2, reason: out);
    expect(out, contains('WARNING: the explicit --timeout looks unsafe'));
    expect(out, contains('measured baseline suite:'));
    expect(out, contains('4 x baseline = '));
    // The honored budget stays the explicit value (1.2s — 0.02 min).
    expect(out, contains('explicit budget: 1.2s'));
    // The warning fires BEFORE any step spawns: the driver prints it
    // in the baseline block (before phase 1), so it must appear before
    // the baseline's own cached line and long before the step failure.
    final warningIndex = out.indexOf(
      'WARNING: the explicit --timeout looks unsafe',
    );
    final stepFailedIndex = out.indexOf('step failed');
    expect(warningIndex, greaterThanOrEqualTo(0));
    expect(stepFailedIndex, greaterThan(warningIndex));
  });

  test('the scaled DEFAULT budget (no --timeout) is handed down as the one '
      'uniform deadline — the 25m floor for a fast measured suite', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'run',
      feature,
      '--project',
      fx.root.path,
      '--zfa-bin',
      fakeZfa1529,
    ]);

    // The fake make green-paths when the argv carries the floor
    // budget; the run completes.
    expect(exitCode, 0, reason: out);
    final log = File(
      p.join(fx.root.path, 'fake_bin_1529', 'zfa_calls.log'),
    ).readAsStringSync().split('\n').where((l) => l.trim().isNotEmpty);
    final makeCall = log.firstWhere((l) => l.contains('tdd make '));
    expect(makeCall, contains('--timeout 25.0000'));
    // No warning without an explicit budget.
    expect(out, isNot(contains('WARNING: the explicit --timeout')));
    // No receipt: nothing was killed.
    expect(
      File(
        p.join(fx.featureDir, 'tdd', 'make.B-001.timeout.json'),
      ).existsSync(),
      isFalse,
    );
  });
}

/// Seed the project-level corpus baseline cache (`.zfa/corpus/`) with a
/// RECORDED capture duration, so the budget scaling reads a known
/// baseline instead of racing a live capture (spec 1529 US2.3). The
/// recorded `command` must equal the profile's suite template and the
/// `dependency_fingerprint` must match the live one, or the driver
/// discards the entry as drift and re-runs the suite.
Future<void> _seedCorpusBaseline(
  TddFixture fx, {
  required int durationMs,
}) async {
  final fingerprint = await const CorpusBaselineCache().dependencyFingerprint(
    fx.root.path,
  );
  final file = File(CorpusBaselineCache.pathFor(projectRoot: fx.root.path));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode({
      'command': _suiteSpyOf(fx),
      'exitCode': 0,
      'failedTests': <String>[],
      'capturedAt': '2026-09-01T00:00:00.000Z',
      'parseable': true,
      'dependency_fingerprint': fingerprint,
      'duration_ms': durationMs,
    }),
  );
}

/// The spec-1529 fake zfa: `verify-red` certifies with a red evidence
/// append; `make` green-paths UNLESS the argv carries the tiny
/// `--timeout 0.0200` (the hang arm — sleep 30, killed at the deadline);
/// `refactor` cleans. Step/behavior ids are parsed like the fixture's
/// stock fake.
Future<void> _writeFakeZfa(TddFixture fx) async {
  final binDir = p.join(fx.root.path, 'fake_bin_1529');
  await Directory(binDir).create(recursive: true);
  final scriptPath = p.join(binDir, 'zfa');
  await File(scriptPath).writeAsString(
    r'''
#!/usr/bin/env bash
ARGV="$*"
HEAD="$1"
STEP="$2"
ID="$3"
FEATURE=""
PROJECT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature) FEATURE="$2"; shift ;;
    --project) PROJECT="$2"; shift ;;
  esac
  shift
done
echo "$ARGV" >> "__ARGVLOG__"
CYCLE="$PROJECT/specs/$FEATURE/tdd/cycle-log.md"
if [ "$HEAD" != "tdd" ]; then
  exit 0
fi
case "$STEP" in
  gen)
    exit 0
    ;;
  verify-red)
    printf '\n## Cycle: %s (red)\n\n- behavior: %s\n- kind: red\n- classification: assertionFailure\n- criterion: FR-001\n- exit: 1\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "verify-red: behavior=$ID classification=assertion certified=true feature=$FEATURE"
    exit 0
    ;;
  make)
    if [[ "$ARGV" == *"--timeout 0.0200"* ]]; then
      # The hang arm: killed by the driver at the 1.2s deadline.
      sleep 30
      exit 99
    fi
    printf '\n## Cycle: %s (green)\n\n- behavior: %s\n- kind: green\n- criterion: FR-001\n- exit: 0\n- at: 2026-08-30T00:00:00.000Z\n' "$ID" "$ID" >> "$CYCLE"
    echo "make: behavior=$ID outcome=green feature=$FEATURE"
    exit 0
    ;;
  refactor)
    echo "refactor: behavior=$ID outcome=clean feature=$FEATURE"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
'''
        .replaceAll('__ARGVLOG__', p.join(binDir, 'zfa_calls.log')),
  );
  await Process.run('chmod', ['+x', scriptPath]);
}
