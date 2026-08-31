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
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

import 'helpers/fixture_corpus.dart';

class _ParseVerdict {
  final bool parsed;
  final String error;
  const _ParseVerdict(this.parsed, this.error);
}

_ParseVerdict _tryParse(String feature, String specMd) {
  try {
    const SpecParser().parse(feature, specMd);
    return const _ParseVerdict(true, '');
  } on StateError catch (e) {
    return _ParseVerdict(false, e.message);
  }
}

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
  }) => const CorpusImporter().import(
    corpus.root.path,
    projectRoot: app.path,
    force: force,
    dryRun: dryRun,
  );

  group('U6 (FR-001): copy', () {
    test(
      'an absent target spec is copied byte-for-byte and reported imported',
      () async {
        final result = await runImport();

        // The import scanned the whole corpus, in manifest order.
        expect(
          result.features.map((f) => f.name).toList(),
          equals(FixtureCorpus.featureNames),
          reason: 'features: ${result.features.map((f) => f.name).toList()}',
        );

        // 001-clean was absent in the target: copied verbatim.
        final target = File(p.join(app.path, 'specs', '001-clean', 'spec.md'));
        expect(target.existsSync(), isTrue);
        final source = File(p.join(corpus.root.path, '001-clean', 'spec.md'));
        expect(
          target.readAsStringSync(),
          equals(source.readAsStringSync()),
          reason: 'spec content must be byte-for-byte identical',
        );

        final feature = result.features.singleWhere(
          (f) => f.name == '001-clean',
        );
        expect(feature.outcome, equals(ImportOutcome.imported));
      },
    );
  });

  group('U10 (FR-001): tdd/ working directory', () {
    test('a per-feature tdd/ directory is created when absent', () async {
      await runImport();

      for (final name in FixtureCorpus.featureNames) {
        expect(
          Directory(p.join(app.path, 'specs', name, 'tdd')).existsSync(),
          isTrue,
          reason: 'missing tdd/ working directory for $name',
        );
      }
    });
  });

  group('U13 (FR-007): foreign artifacts', () {
    test('foreign artifacts are reported and ignored — never copied, converted '
        'or deleted', () async {
      final result = await runImport();

      final feature = result.features.singleWhere(
        (f) => f.name == '003-speckit',
      );
      expect(feature.hasForeignArtifacts, isTrue);
      expect(feature.ignoredArtifacts, containsAll(['checklists', 'tdd']));

      // Only spec.md crossed into the target for 003-speckit.
      final importedDir = Directory(p.join(app.path, 'specs', '003-speckit'));
      final entries = importedDir.listSync(recursive: true).map((e) {
        return p.basename(e.path);
      }).toSet();
      expect(entries, equals({'spec.md', 'tdd'}));
      // The tdd/ dir import created is empty — the foreign test list
      // inside the source's tdd/ never crossed over.
      expect(
        Directory(p.join(app.path, 'specs', '003-speckit', 'tdd')).listSync(),
        isEmpty,
      );

      // The source's foreign artifacts are untouched (ignored, not
      // consumed).
      expect(
        File(
          p.join(
            corpus.root.path,
            '003-speckit',
            'checklists',
            'requirements.md',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(corpus.root.path, '003-speckit', 'tdd', 'test-list.md'),
        ).existsSync(),
        isTrue,
      );

      // The clean features carry no foreign-artifact flag.
      expect(
        result.features
            .singleWhere((f) => f.name == '001-clean')
            .hasForeignArtifacts,
        isFalse,
      );
    });
  });

  group('U15 (FR-005): report + summary line', () {
    test(
      'the per-feature report lines and summary line match the contract',
      () async {
        final result = await runImport();

        expect(
          result.reportLines,
          equals([
            '001-clean: imported',
            '002-no-scenarios: imported not-ready '
                '(no acceptance scenarios)',
            '003-speckit: imported foreign-artifacts-ignored '
                '(checklists, tdd)',
          ]),
          reason: 'report lines:\n${result.reportLines.join('\n')}',
        );
        expect(
          result.summaryLine,
          equals(
            'corpus import: 3 features — 3 imported, 0 skipped, '
            '0 divergent, 1 not-ready (manifest: '
            '${p.join(app.path, '.zfa', 'manifests', 'corpus-manifest.json')})',
          ),
          reason: 'summary line:\n${result.summaryLine}',
        );
      },
    );
  });

  group('U12 (FR-006): loop-readiness mark', () {
    test(
      'the mark equals the SpecParser verdict and carries its reason',
      () async {
        final result = await runImport();

        for (final feature in result.features) {
          final specMd = File(
            p.join(corpus.root.path, feature.name, 'spec.md'),
          ).readAsStringSync();
          final verdict = _tryParse(feature.name, specMd);
          expect(
            feature.ready,
            equals(verdict.parsed),
            reason:
                'mark for ${feature.name} must equal the SpecParser verdict',
          );
          if (verdict.parsed) {
            expect(feature.reason, isEmpty);
          } else {
            expect(feature.reason, isNotEmpty);
            // The reason is derived from the parser's own failure message.
            expect(verdict.error, contains(feature.reason));
          }
        }

        // The fixture's known verdicts, pinned:
        final byName = {for (final f in result.features) f.name: f};
        expect(byName['001-clean']!.ready, isTrue);
        expect(byName['003-speckit']!.ready, isTrue);
        expect(byName['002-no-scenarios']!.ready, isFalse);
        expect(
          byName['002-no-scenarios']!.reason,
          contains('no acceptance scenarios'),
        );
      },
    );
  });

  group('U5 (FR-001): source validation', () {
    test('accepts a corpus root', () async {
      await runImport();
    });

    test('rejects a single-feature path with a clear message', () async {
      // A single feature directory: contains spec.md directly.
      final single = Directory.systemTemp.createTempSync('zfa_single_fx_');
      addTearDown(() => single.deleteSync(recursive: true));
      File(
        p.join(single.path, 'spec.md'),
      ).writeAsStringSync(FixtureCorpus.cleanSpec('stray-feature'));

      await expectLater(
        const CorpusImporter().import(single.path, projectRoot: app.path),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('single feature'), contains('corpus root')),
          ),
        ),
      );
    });
  });
}
