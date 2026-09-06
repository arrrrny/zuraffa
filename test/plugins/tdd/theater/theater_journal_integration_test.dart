// Theater ↔ JournalReader integration (spec 1113-unified-tdd-journal,
// issue #1113): the theater's data layer loads the unified journal
// through the ONE canonical reader — the snapshot carries the entries
// and the derived verdict, and the cycle-log CONTENT the timeline
// parses comes from the journal stream, not a direct file read.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/journal.dart';
import 'package:zuraffa/src/plugins/tdd/services/theater_data.dart';

import 'theater_fixture.dart';

void main() {
  test('J-012: theater loads the journal through JournalReader (entries + '
      'verdict + cycle-log content)', () async {
    final fx = await TheaterFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));

    // Seed the unified journal the way the run commands write it: an
    // engine entry, a skin entry, a meta entry, and the two lane
    // receipts the refs point at.
    final featureDir = fx.featureDir;
    final writer = JournalWriter(featureDir);
    await _writeReceipt(featureDir, '04-engine-receipt.json', {
      'schema': 1,
      'feature': fx.featureName,
      'lane': 'engine',
      'verdict': 'green',
      'result': 'complete',
      'behaviors': ['A1', 'A2'],
      'counts': {'total': 2, 'pending': 0, 'red': 0, 'green': 0, 'done': 2},
      'stopped_at': null,
      'at': '2026-09-06T00:00:00.000Z',
    });
    await _writeReceipt(featureDir, '04-skin-receipt.json', {
      'schema': 1,
      'feature': fx.featureName,
      'lane': 'skin',
      'verdict': 'green',
      'result': 'complete',
      'behaviors': ['A1'],
      'counts': {'total': 1, 'pending': 0, 'red': 0, 'green': 0, 'done': 1},
      'stopped_at': null,
      'at': '2026-09-06T00:00:00.000Z',
    });
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in [
      JournalEntry(
        feature: fx.featureName,
        cycle: 'engine',
        phase: 'drive',
        startedAt: now,
        finishedAt: now,
        gateState: 'green',
        receipts: [JournalWriter.engineReceiptRef],
        engineReceipt: JournalWriter.engineReceiptRef,
      ),
      JournalEntry(
        feature: fx.featureName,
        cycle: 'skin',
        phase: 'drive',
        startedAt: now,
        finishedAt: now,
        gateState: 'green',
        receipts: [JournalWriter.skinReceiptRef],
        skinReceipt: JournalWriter.skinReceiptRef,
      ),
      JournalEntry(
        feature: fx.featureName,
        cycle: 'meta',
        phase: 'aggregate',
        startedAt: now,
        finishedAt: now,
        gateState: 'green',
        receipts: [
          JournalWriter.engineReceiptRef,
          JournalWriter.skinReceiptRef,
        ],
        engineReceipt: JournalWriter.engineReceiptRef,
        skinReceipt: JournalWriter.skinReceiptRef,
      ),
    ]) {
      await writer.append(entry);
    }

    final snapshot = await TheaterData.load(
      feature: fx.featureName,
      projectRoot: fx.root.path,
    );

    // The snapshot carries the journal — the entries and the derived
    // verdict the bottom status line renders.
    expect(snapshot.journal.journalPresent, isTrue);
    expect(snapshot.journal.entries.map((e) => e.cycle).toList(), [
      'engine',
      'skin',
      'meta',
    ]);
    expect(snapshot.journal.verdict.engineVerdict, 'green');
    expect(snapshot.journal.verdict.skinVerdict, 'green');
    expect(snapshot.journal.verdict.engineDone, 2);
    expect(snapshot.journal.verdict.oneLine, contains('engine ✅ 2/2'));
    // The cycle-log timeline still renders — parsed from the CONTENT
    // the journal stream handed the theater, not a direct file read.
    expect(snapshot.cycles, isNotEmpty);
    expect(snapshot.cycleLogPresent, isTrue);
  });

  test('J-013: a feature with no journal is honest pending state, never an '
      'error (theater still loads)', () async {
    final fx = await TheaterFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));

    final snapshot = await TheaterData.load(
      feature: fx.featureName,
      projectRoot: fx.root.path,
    );

    expect(snapshot.journal.journalPresent, isFalse);
    expect(snapshot.journal.entries, isEmpty);
    expect(snapshot.journal.verdict.engineVerdict, 'absent');
    expect(snapshot.cycles, isNotEmpty);
  });

  test('J-014: the reader is the single file boundary — theater parses the '
      'cycle-log STRING, the reader owns the READ', () async {
    final fx = await TheaterFixture.create();
    addTearDown(() => fx.root.delete(recursive: true));

    // The reader hands out the same content the file carries; the
    // theater's snapshot cycles are the parse of THAT string.
    final journal = await const JournalReader().read(
      feature: fx.featureName,
      projectRoot: fx.root.path,
    );
    final snapshot = await TheaterData.load(
      feature: fx.featureName,
      projectRoot: fx.root.path,
    );

    expect(journal.cycleLog, equals(snapshot.journal.cycleLog));
    expect(
      snapshot.cycles.length,
      greaterThanOrEqualTo(journal.cycleLog.split('## ').length - 1),
    );
  });
}

Future<void> _writeReceipt(
  String featureDir,
  String name,
  Map<String, dynamic> doc,
) async {
  final file = File(p.join(featureDir, 'tdd', name));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(doc)}\n',
  );
}
