// Issue #1007 ([VISION] Contract tests as first-class zfa tdd test kind):
// the corpus-economics gate treats contract-test failures as
// highest-severity gaps.
//
// - Gap ledger entries carry an optional `severity` (backward-compatible
//   JSON: absent on legacy entries, byte-stable for previously appended
//   ones).
// - GapLedgerTotals ranks contract-severity gaps FIRST among open and
//   blocking gaps and counts them.
// - The corpus run stamps severity=contract on stops whose behavior is a
//   contract behavior (or whose outcome token is blocked).
//
// RED phase: no severity exists anywhere — the assertions fail.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger_store.dart';

void main() {
  late Directory tmpDir;
  late GapLedgerStore store;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('severity_1007_');
    store = GapLedgerStore(
      tmpDir.path,
      clock: () => DateTime.parse('2026-09-05T00:00:00Z'),
    );
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('appendGap stamps and reloads the contract severity (FR-006)', () async {
    final gap = await store.appendGap(
      feature: '004-login-ui',
      behavior: 'contract:A1',
      step: 'run',
      outcome: 'blocked',
      expectedResult: 'complete',
      severity: GapSeverity.contract,
    );
    expect(gap.severity, GapSeverity.contract);

    final reloaded = await store.load();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.severity, GapSeverity.contract);

    // The serialized document carries the severity field.
    final raw =
        jsonDecode(await File(store.path).readAsString()) as List<dynamic>;
    expect(raw.single['severity'], 'contract');
  });

  test('legacy entries without severity still parse (null severity)', () async {
    final legacy = [
      {
        'id': 'gap-001',
        'kind': 'gap',
        'at': '2026-09-05T00:00:00Z',
        'feature': '004-login-ui',
        'behavior': 'U1',
        'step': 'run',
        'outcome': 'stopped',
        'expected_result': 'complete',
        'status': 'open',
      },
    ];
    await Directory(p.dirname(store.path)).create(recursive: true);
    await File(store.path).writeAsString(jsonEncode(legacy));
    final entries = await store.load();
    expect(entries.single.severity, isNull);
  });

  test('a severity-carrying append keeps previously-appended entries '
      'byte-stable (U13 fixed field order)', () async {
    await store.appendGap(
      feature: '004-login-ui',
      behavior: 'U1',
      step: 'run',
      outcome: 'stopped',
      expectedResult: 'complete',
    );
    final bytesAfterFirst = await File(store.path).readAsString();
    await store.appendGap(
      feature: '004-login-ui',
      behavior: 'contract:A1',
      step: 'run',
      outcome: 'blocked',
      expectedResult: 'complete',
      severity: GapSeverity.contract,
    );
    final bytesAfterSecond = await File(store.path).readAsString();
    // The gap entries serialize FLAT (no nested objects), so each
    // `\{...\}` span is one entry's exact serialization.
    final entry = RegExp(r'\{[^{}]+\}');
    final firstEntry = entry.firstMatch(bytesAfterFirst)!.group(0)!;
    final second = entry
        .allMatches(bytesAfterSecond)
        .map((m) => m.group(0)!)
        .toList();
    // The previously-appended entry is byte-identical.
    expect(second[0], firstEntry);
    // The severity key renders LAST in the new entry — after every
    // existing key (the U13 fixed-field-order contract).
    final keys = RegExp(
      r'"([a-z_]+)":',
    ).allMatches(second[1]).map((m) => m.group(1)!).toList();
    expect(keys.last, 'severity');
  });

  test('GapLedgerTotals ranks contract gaps first and counts them', () async {
    final entries = <GapLedgerEntry>[
      GapLedgerEntry.gap(
        id: 'gap-001',
        at: '2026-09-05T00:00:00Z',
        feature: '004-login-ui',
        behavior: 'U1',
        step: 'run',
        outcome: 'stopped',
        expectedResult: 'complete',
      ),
      GapLedgerEntry.gap(
        id: 'gap-002',
        at: '2026-09-05T00:00:01Z',
        feature: '004-login-ui',
        behavior: 'contract:A1',
        step: 'run',
        outcome: 'blocked',
        expectedResult: 'complete',
        severity: GapSeverity.contract,
      ),
      GapLedgerEntry.gap(
        id: 'gap-003',
        at: '2026-09-05T00:00:02Z',
        feature: '005-other',
        behavior: 'A2',
        step: 'verify',
        outcome: 'fail_survived',
        expectedResult: 'pass',
      ),
    ];
    final totals = GapLedgerTotals.fromEntries(entries, doneFeatures: const {});
    expect(totals.open, hasLength(3));
    expect(totals.contract, 1);
    // Highest severity first: the contract gap heads both lists.
    expect(totals.open.first.id, 'gap-002');
    expect(totals.blocking.first.id, 'gap-002');
    // Ranking is stable for same-severity gaps (append order).
    expect(totals.open[1].id, 'gap-001');
    expect(totals.open[2].id, 'gap-003');
  });

  test('GapSeverity.forStop classifies contract stops (FR-006)', () {
    // A contract behavior id (the plan's contract:<id> grammar).
    expect(
      GapSeverity.forStop(behavior: 'contract:A1', outcome: 'stopped'),
      GapSeverity.contract,
    );
    // A blocked outcome token on any behavior.
    expect(
      GapSeverity.forStop(behavior: 'U1', outcome: 'blocked'),
      GapSeverity.contract,
    );
    // Everything else is the standard severity.
    expect(
      GapSeverity.forStop(behavior: 'U1', outcome: 'stopped'),
      GapSeverity.standard,
    );
    expect(
      GapSeverity.forStop(behavior: null, outcome: 'fail_survived'),
      GapSeverity.standard,
    );
  });
}
