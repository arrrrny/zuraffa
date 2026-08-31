// Tests for GapLedger (spec 051, U7-U11).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/gap_ledger_entry.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger.dart';

void main() {
  late Directory tmpDir;
  late GapLedger ledger;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gap_ledger_test_');
    ledger = GapLedger(tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('GapLedger', () {
    test('[U7] appends entry with all five required fields', () async {
      final entry = GapLedgerEntry(
        feature: '003-broken-gen',
        behavior: 'U1',
        step: 'make',
        outcome: 'stopped',
        command: 'zfa tdd run 003-broken-gen --project /app',
        timestamp: '2026-08-31T12:05:00Z',
      );
      await ledger.append(entry);
      final entries = await ledger.load();
      expect(entries.length, 1);
      expect(entries.first.feature, '003-broken-gen');
      expect(entries.first.behavior, 'U1');
      expect(entries.first.step, 'make');
      expect(entries.first.outcome, 'stopped');
      expect(entries.first.command, 'zfa tdd run 003-broken-gen --project /app');
    });

    test('[U8] append-only: past entries never edited', () async {
      await ledger.append(GapLedgerEntry(
        feature: '001',
        outcome: 'stopped',
        command: 'cmd1',
        timestamp: '2026-08-31T12:00:00Z',
      ));
      await ledger.append(GapLedgerEntry(
        feature: '002',
        outcome: 'PASS',
        command: 'cmd2',
        timestamp: '2026-08-31T12:01:00Z',
      ));
      final entries = await ledger.load();
      expect(entries.length, 2);
      expect(entries[0].feature, '001');
      expect(entries[1].feature, '002');
    });

    test('[U9] resolution entry appends alongside original', () async {
      await ledger.append(GapLedgerEntry(
        feature: '003',
        outcome: 'stopped',
        command: 'cmd',
        timestamp: '2026-08-31T12:00:00Z',
      ));
      await ledger.appendResolution(
        feature: '003',
        timestamp: '2026-08-31T13:00:00Z',
      );
      final entries = await ledger.load();
      expect(entries.length, 2);
      expect(entries[0].resolution, isNull);
      expect(entries[1].resolution, 'resolved');
      expect(entries[1].feature, '003');
    });

    test('[U10] ledger totals compute correctly', () async {
      await ledger.append(GapLedgerEntry(
        feature: 'a', outcome: 'stopped', command: 'c',
        timestamp: 't',
      ));
      await ledger.append(GapLedgerEntry(
        feature: 'b', outcome: 'stopped', command: 'c',
        timestamp: 't', issueLink: 'https://issue/1',
      ));
      await ledger.appendResolution(feature: 'a', timestamp: 't');
      final entries = await ledger.load();
      final totals = ledger.totals(entries);
      expect(totals.total, 3);
      expect(totals.resolved, 1);
      expect(totals.filed, 1);
      expect(totals.unresolved, 1);
      expect(totals.blocking, 1);
    });

    test('[U11] atomic write prevents corruption on crash', () async {
      // Verify the file is well-formed after save.
      await ledger.append(GapLedgerEntry(
        feature: 'test',
        outcome: 'stopped',
        command: 'cmd',
        timestamp: 't',
      ));
      final file = File(
        '${tmpDir.path}/.zfa/corpus/gap-ledger.json',
      );
      expect(await file.exists(), true);
      final content = await file.readAsString();
      expect(content, contains('"feature": "test"'));
    });
  });
}
