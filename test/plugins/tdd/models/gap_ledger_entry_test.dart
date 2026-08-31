// Tests for GapLedgerEntry model (spec 051).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/gap_ledger_entry.dart';

void main() {
  group('GapLedgerEntry', () {
    test('toJson and fromJson round-trip with all fields', () {
      final entry = GapLedgerEntry(
        feature: '003-broken-gen',
        behavior: 'U1',
        step: 'make',
        outcome: 'stopped',
        command: 'zfa tdd run 003-broken-gen --project /app',
        issueLink: 'https://github.com/arrrrny/zuraffa/issues/700',
        timestamp: '2026-08-31T12:05:00Z',
        resolution: null,
      );
      final json = entry.toJson();
      final entry2 = GapLedgerEntry.fromJson(json);
      expect(entry2.feature, '003-broken-gen');
      expect(entry2.behavior, 'U1');
      expect(entry2.step, 'make');
      expect(entry2.outcome, 'stopped');
      expect(entry2.command, 'zfa tdd run 003-broken-gen --project /app');
      expect(entry2.issueLink, 'https://github.com/arrrrny/zuraffa/issues/700');
      expect(entry2.timestamp, '2026-08-31T12:05:00Z');
      expect(entry2.resolution, isNull);
    });

    test('toJson and fromJson round-trip with minimal fields', () {
      final entry = GapLedgerEntry(
        feature: '001-ready',
        outcome: 'PASS',
        command: 'zfa tdd run 001-ready',
        timestamp: '2026-08-31T12:00:00Z',
      );
      final json = entry.toJson();
      final entry2 = GapLedgerEntry.fromJson(json);
      expect(entry2.feature, '001-ready');
      expect(entry2.behavior, isNull);
      expect(entry2.step, isNull);
      expect(entry2.outcome, 'PASS');
      expect(entry2.issueLink, isNull);
      expect(entry2.resolution, isNull);
    });

    test('resolution field round-trips', () {
      final entry = GapLedgerEntry(
        feature: '003-broken-gen',
        outcome: 'resolved',
        command: 'zfa tdd run 003-broken-gen',
        timestamp: '2026-08-31T13:00:00Z',
        resolution: 'resolved',
      );
      final json = entry.toJson();
      final entry2 = GapLedgerEntry.fromJson(json);
      expect(entry2.resolution, 'resolved');
    });
  });
}
