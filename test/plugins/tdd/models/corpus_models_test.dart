// Tests for the corpus models (spec 051-corpus-harness, U1-U2 manifest,
// U6 progress, U11 ledger totals).
library;

import 'package:test/test.dart';
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
}
