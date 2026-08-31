// Tests for `CorpusManifest` / `CorpusFeature` (spec 050-corpus-import,
// task T004; behaviors U1-U4, traced to FR-002 / SC-004).
//
// The manifest is the contract between corpus import and batch driving
// (#628): an ordered, machine-readable feature list with readiness marks,
// stored at `.zfa/manifests/corpus-manifest.json` via
// `ProjectPaths.manifestsDirectory`. Fast tier: pure file I/O.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/corpus_manifest.dart';

void main() {
  late Directory projectRoot;

  setUp(() {
    projectRoot = Directory.systemTemp.createTempSync('zfa_corpus_manifest_');
  });

  tearDown(() {
    if (projectRoot.existsSync()) projectRoot.deleteSync(recursive: true);
  });

  CorpusManifest makeManifest() => CorpusManifest(
    features: const [
      CorpusFeature(
        name: '002-no-scenarios',
        ready: false,
        reason:
            'no '
            'acceptance scenarios',
      ),
      CorpusFeature(name: '001-clean', ready: true, reason: ''),
      CorpusFeature(name: '003-speckit', ready: true, reason: ''),
    ],
    sourceCorpus: '/tmp/fx-corpus',
    importedAt: '2026-09-01T00:00:00.000Z',
  );

  group('U1 (FR-002): json round-trip', () {
    test('round-trips features, sourceCorpus and importedAt', () {
      final manifest = makeManifest();

      final restored = CorpusManifest.fromJson(manifest.toJson());

      expect(restored.sourceCorpus, equals('/tmp/fx-corpus'));
      expect(restored.importedAt, equals('2026-09-01T00:00:00.000Z'));
      expect(
        restored.features.map((f) => f.name).toSet(),
        equals({'002-no-scenarios', '001-clean', '003-speckit'}),
      );
      // (order is U2's behavior — U1 pins the content round-trip only)
      final byName = {for (final f in restored.features) f.name: f};
      final notReady = byName['002-no-scenarios']!;
      expect(notReady.ready, isFalse);
      expect(notReady.reason, equals('no acceptance scenarios'));
      final clean = byName['001-clean']!;
      expect(clean.ready, isTrue);
      expect(clean.reason, isEmpty);
    });
  });

  group('U2 (FR-002): deterministic lexicographic order', () {
    test('features serialize in lexicographic order however constructed', () {
      // Constructed out of order (002, 001, 003) — the serialized form
      // must still list features in deterministic lexicographic order.
      final manifest = makeManifest();

      final json = manifest.toJson();
      final names = (json['features'] as List)
          .map((f) => (f as Map)['name'] as String)
          .toList();

      expect(names, equals(['001-clean', '002-no-scenarios', '003-speckit']));

      // And the order survives a round-trip.
      final restored = CorpusManifest.fromJson(json);
      expect(
        restored.features.map((f) => f.name).toList(),
        equals(['001-clean', '002-no-scenarios', '003-speckit']),
      );
    });
  });

  group('U3 (SC-004): manifest stability', () {
    test('write→read is byte-stable across identical re-imports except '
        'importedAt', () async {
      final first = makeManifest();
      await first.write(projectRoot.path);

      final readBack = CorpusManifest.read(projectRoot.path);
      expect(readBack, isNotNull);
      expect(readBack!.toJson(), equals(first.toJson()));

      // Identical re-import at a later time: the file content is
      // byte-identical except the imported_at field.
      final second = CorpusManifest(
        features: first.features,
        sourceCorpus: first.sourceCorpus,
        importedAt: '2026-09-02T00:00:00.000Z',
      );
      await second.write(projectRoot.path);

      final raw1 = manifestFileFor(projectRoot.path).readAsStringSync();
      // Re-read the first write's content through the model to keep the
      // comparison honest: rewrite `first` after `second`.
      await first.write(projectRoot.path);
      final raw2 = manifestFileFor(projectRoot.path).readAsStringSync();

      String stripImportedAt(String raw) => raw.replaceAll(
        RegExp(r'"imported_at":\s*"[^"]*"'),
        '"imported_at": "<ts>"',
      );
      expect(
        stripImportedAt(raw2),
        equals(stripImportedAt(raw1)),
        reason: 'manifest not byte-stable:\n$raw1\n--\n$raw2',
      );
    });
  });

  group('U4 (FR-002): missing manifest', () {
    test('reads as null (not an error) on a fresh project', () {
      // A fresh app has no `.zfa/` at all.
      expect(CorpusManifest.read(projectRoot.path), isNull);

      // Nor when `.zfa/manifests/` exists but the manifest does not.
      Directory(
        p.join(projectRoot.path, '.zfa', 'manifests'),
      ).createSync(recursive: true);
      expect(CorpusManifest.read(projectRoot.path), isNull);
    });
  });
}

File manifestFileFor(String projectRoot) =>
    File(p.join(projectRoot, '.zfa', 'manifests', 'corpus-manifest.json'));
