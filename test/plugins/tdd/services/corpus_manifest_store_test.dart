// Tests for CorpusManifestStore (spec 051-corpus-harness, U3-U5): the
// manifest / carve-out / waivers readers and the `.zfa/` path constants.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_manifest.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_manifest_store.dart';

void main() {
  late Directory root;
  late CorpusManifestStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('corpus_store_');
    store = CorpusManifestStore(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<File> write(String relPath, String content) async {
    final file = File(p.join(root.path, relPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  group('CorpusManifestStore paths', () {
    test('.zfa/ constants resolve under the project root', () {
      expect(
        store.manifestPath,
        p.join(root.path, '.zfa', 'manifests', 'corpus-manifest.json'),
      );
      expect(
        store.carveOutPath,
        p.join(root.path, '.zfa', 'manifests', 'corpus-carveout.json'),
      );
      expect(
        store.waiversPath,
        p.join(root.path, '.zfa', 'corpus', 'waivers.json'),
      );
      expect(
        store.provenanceDir,
        p.join(root.path, '.zfa', 'provenance'),
      );
    });
  });

  group('U3 — manifest reading', () {
    test('absent manifest -> CorpusManifestMissingException naming the path',
        () async {
      expect(
        () => store.readManifest(),
        throwsA(
          isA<CorpusManifestMissingException>().having(
            (e) => e.message,
            'message',
            allOf(contains('corpus-manifest.json'), contains(root.path)),
          ),
        ),
      );
    });

    test('a present manifest decodes through the model in file order', () async {
      await write('.zfa/manifests/corpus-manifest.json', jsonEncode({
        'features': [
          {'name': 'b-second', 'ready': true},
          {'name': 'a-first', 'ready': false, 'reason': 'not loop-ready'},
        ],
      }));
      final manifest = await store.readManifest();
      expect(
        manifest.features.map((f) => f.name).toList(),
        ['b-second', 'a-first'],
      );
    });

    test('invalid manifest JSON text -> CorpusCorruptException', () async {
      await write('.zfa/manifests/corpus-manifest.json', '{not json');
      expect(
        () => store.readManifest(),
        throwsA(isA<CorpusCorruptException>()),
      );
    });
  });

  group('U4 — carve-out reading', () {
    test('decodes {carveouts: [{path, reason}]}', () async {
      await write('.zfa/manifests/corpus-carveout.json', jsonEncode({
        'carveouts': [
          {'path': 'lib/manual_ui.dart', 'reason': 'manual UI (epic 045)'},
        ],
      }));
      final entries = await store.readCarveOut();
      expect(entries, hasLength(1));
      expect(entries.single.path, 'lib/manual_ui.dart');
      expect(entries.single.reason, 'manual UI (epic 045)');
    });

    test('absent carve-out -> empty list', () async {
      expect(await store.readCarveOut(), isEmpty);
    });

    test('malformed carve-out shape -> CorpusCorruptException naming the file',
        () async {
      await write('.zfa/manifests/corpus-carveout.json', jsonEncode({
        'carveouts': [
          {'reason': 'no path'},
        ],
      }));
      expect(
        () => store.readCarveOut(),
        throwsA(
          isA<CorpusCorruptException>().having(
            (e) => e.message,
            'message',
            contains('corpus-carveout.json'),
          ),
        ),
      );
    });
  });

  group('U5 — waivers reading', () {
    test('decodes rows {feature, gate, reason, actor, at}', () async {
      await write('.zfa/corpus/waivers.json', jsonEncode([
        {
          'feature': 'f2-gap',
          'gate': 'not_assessed',
          'reason': 'mutation tool unavailable on CI',
          'actor': 'maintainer',
          'at': '2026-08-31T01:00:00Z',
        },
      ]));
      final waivers = await store.readWaivers();
      expect(waivers, hasLength(1));
      expect(waivers.single.feature, 'f2-gap');
      expect(waivers.single.gate, 'not_assessed');
      expect(waivers.single.reason, 'mutation tool unavailable on CI');
      expect(waivers.single.actor, 'maintainer');
      expect(waivers.single.at, '2026-08-31T01:00:00Z');
    });

    test('absent waivers file -> no waivers', () async {
      expect(await store.readWaivers(), isEmpty);
    });

    test('malformed waivers shape -> CorpusCorruptException naming the file',
        () async {
      await write('.zfa/corpus/waivers.json', jsonEncode([
        {'feature': 'f2-gap'}, // missing gate/reason/actor/at
      ]));
      expect(
        () => store.readWaivers(),
        throwsA(
          isA<CorpusCorruptException>().having(
            (e) => e.message,
            'message',
            contains('waivers.json'),
          ),
        ),
      );
    });
  });
}
