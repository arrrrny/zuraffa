// Tests for `CorpusImporter` (spec 050-corpus-import, tasks T005/T006/
// T010/T011/T013; behaviors U5-U15, traced to FR-001..FR-007).
//
// Drives the shared import service both `zfa corpus import` and
// `zfa setup --specs` delegate to, against the fixture corpus matrix.
// Fast tier: pure file I/O — no subprocess, no network.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/services/corpus_importer.dart';

import 'helpers/fixture_corpus.dart';

void main() {
  late FixtureCorpus corpus;
  late Directory app;

  setUp(() {
    corpus = FixtureCorpus.create();
    app = Directory.systemTemp.createTempSync('zfa_corpus_target_');
  });

  tearDown(() {
    corpus.dispose();
    if (app.existsSync()) app.deleteSync(recursive: true);
  });

  Future<CorpusImportResult> runImport({
    bool force = false,
    bool dryRun = false,
  }) =>
      const CorpusImporter().import(
        corpus.root.path,
        projectRoot: app.path,
        force: force,
        dryRun: dryRun,
      );

  group('U5 (FR-001): source validation', () {
    test('accepts a corpus root', () async {
      await runImport();
    });

    test(
      'rejects a single-feature path with a clear message',
      () async {
        // A single feature directory: contains spec.md directly.
        final single = Directory.systemTemp.createTempSync('zfa_single_fx_');
        addTearDown(() => single.deleteSync(recursive: true));
        File(p.join(single.path, 'spec.md')).writeAsStringSync(
          FixtureCorpus.cleanSpec('stray-feature'),
        );

        await expectLater(
          const CorpusImporter().import(
            single.path,
            projectRoot: app.path,
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('single feature'), contains('corpus root')),
            ),
          ),
        );
      },
    );
  });
}
