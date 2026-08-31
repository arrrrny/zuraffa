// Tests for the corpus models (spec 051-corpus-harness, U1-U2 manifest,
// U6 progress, U11 ledger totals).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_manifest.dart';

void main() {
  group('CorpusManifest (U1)', () {
    test('decodes features in file order with optional provenance', () {
      final manifest = CorpusManifest.fromJson({
        'features': [
          {'name': 'f1-good', 'ready': true, 'reason': ''},
          {'name': 'f2-gap', 'ready': true, 'reason': ''},
          {'name': 'f3-later', 'ready': false, 'reason': 'no acceptance'},
        ],
        'sourceCorpus': '/corpus',
        'importedAt': '2026-08-31T00:00:00Z',
      });
      // Order IS the driving order (FR-001) — never re-sorted.
      expect(
        manifest.features.map((f) => f.name).toList(),
        ['f1-good', 'f2-gap', 'f3-later'],
      );
      expect(manifest.features[2].ready, isFalse);
      expect(manifest.features[2].reason, 'no acceptance');
      expect(manifest.sourceCorpus, '/corpus');
      expect(manifest.importedAt, '2026-08-31T00:00:00Z');
    });

    test('decodes without sourceCorpus/importedAt and defaults reason', () {
      final manifest = CorpusManifest.fromJson({
        'features': [
          {'name': 'solo', 'ready': true},
        ],
      });
      expect(manifest.features.single.name, 'solo');
      expect(manifest.features.single.reason, '');
      expect(manifest.sourceCorpus, isNull);
      expect(manifest.importedAt, isNull);
    });
  });

  group('CorpusManifest malformed (U2)', () {
    test('rejects a non-object root naming the file and recovery', () {
      expect(
        () => CorpusManifest.fromJson(<dynamic>[1, 2]),
        throwsA(
          isA<CorpusManifestException>().having(
            (e) => e.message,
            'message',
            allOf(contains('corpus-manifest.json'), contains('Recovery')),
          ),
        ),
      );
    });

    test('rejects features that is not a list', () {
      expect(
        () => CorpusManifest.fromJson({
          'features': {'name': 'x'},
        }),
        throwsA(isA<CorpusManifestException>()),
      );
    });

    test('rejects a row missing name or ready', () {
      expect(
        () => CorpusManifest.fromJson({
          'features': [
            {'ready': true},
          ],
        }),
        throwsA(
          isA<CorpusManifestException>().having(
            (e) => e.message,
            'message',
            contains('name'),
          ),
        ),
      );
      expect(
        () => CorpusManifest.fromJson({
          'features': [
            {'name': 'x'},
          ],
        }),
        throwsA(
          isA<CorpusManifestException>().having(
            (e) => e.message,
            'message',
            contains('ready'),
          ),
        ),
      );
    });

    test('rejects a non-bool ready and a non-object row', () {
      expect(
        () => CorpusManifest.fromJson({
          'features': [
            {'name': 'x', 'ready': 'yes'},
          ],
        }),
        throwsA(isA<CorpusManifestException>()),
      );
      expect(
        () => CorpusManifest.fromJson({
          'features': ['x'],
        }),
        throwsA(isA<CorpusManifestException>()),
      );
    });
  });

  group('GapLedger totals (U11)', () {
    test('computes found / filed / merged / blocking from entries', () {
      final entries = [
        GapLedgerEntry.gap(
          id: 'gap-001',
          at: '2026-08-31T00:00:00Z',
          feature: 'f2-gap',
          behavior: 'B-002',
          step: 'run',
          outcome: 'stopped',
          failingCommand: 'zfa tdd run f2-gap --project .',
        ), // open, no issue link
        GapLedgerEntry.gap(
          id: 'gap-002',
          at: '2026-08-31T01:00:00Z',
          feature: 'f4-gap',
          behavior: null,
          step: 'verify',
          outcome: 'not_assessed',
          failingCommand: 'zfa tdd verify --feature f4-gap',
          issueLink: 'https://github.com/arrrrny/zuraffa/issues/640',
        ), // filed
        GapLedgerEntry.gap(
          id: 'gap-003',
          at: '2026-08-31T02:00:00Z',
          feature: 'f5-gap',
          step: 'verify',
          outcome: 'fail_survived',
          failingCommand: 'zfa tdd verify --feature f5-gap',
          status: 'merged',
          issueLink: 'https://github.com/arrrrny/zuraffa/issues/641',
        ), // merged (fixed in zuraffa)
        GapLedgerEntry.resolution(
          id: 'res-001',
          at: '2026-08-31T03:00:00Z',
          feature: 'f6-gap',
          resolves: 'gap-004',
        ),
        GapLedgerEntry.gap(
          id: 'gap-004',
          at: '2026-08-31T02:30:00Z',
          feature: 'f6-gap',
          step: 'verify',
          outcome: 'preflight_red',
          failingCommand: 'zfa tdd verify --feature f6-gap',
        ), // resolved by res-001
      ];
      final totals = GapLedgerTotals.fromEntries(
        entries,
        doneFeatures: const {'f9-done'},
      );
      expect(totals.found, 4, reason: 'gap entries only');
      expect(totals.filed, 2, reason: 'issue links set (gap-002, gap-003)');
      expect(totals.merged, 1, reason: 'status merged (gap-003)');
      // Blocking: unresolved gaps whose feature is not done/waived —
      // gap-001 (open) and gap-002 (filed but not merged — filing an
      // issue does not unblock completion). gap-003 merged, gap-004
      // resolved by res-001, f9-done is done.
      expect(totals.blocking, hasLength(2));
      expect(
        totals.blocking.map((g) => g.id).toList(),
        ['gap-001', 'gap-002'],
      );
    });
  });
}

