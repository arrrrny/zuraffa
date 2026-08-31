// Acceptance + command tests for `zfa corpus import` (spec
// 050-corpus-import, tasks T007/T019/T020/T021).
//
// Acceptance behaviors A1-A8 trace 1:1 to spec.md's acceptance scenarios:
// they drive the real CLI entry point (CliRunner.runCapturing) against a
// temp "app" project and the fixture corpus matrix from
// test/cli/services/helpers/fixture_corpus.dart, asserting only on
// observable effects (files on disk, the manifest JSON, captured output).
//
// Fast tier: pure file I/O through the in-process runner — no subprocess
// suites, no network.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/corpus_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

import '../cli/services/helpers/fixture_corpus.dart';

void main() {
  late FixtureCorpus corpus;
  late Directory app;

  setUp(() {
    corpus = FixtureCorpus.create();
    app = Directory.systemTemp.createTempSync('zfa_corpus_app_');
  });

  tearDown(() {
    corpus.dispose();
    if (app.existsSync()) app.deleteSync(recursive: true);
  });

  /// Runs `zfa corpus import <source> [--dry-run] [--force]` against the
  /// temp app root, returning the captured CLI output.
  Future<String> importCorpus({bool dryRun = false, bool force = false}) {
    final runner = CliRunner(exitOnCompletion: false);
    final args = [
      'corpus',
      'import',
      corpus.root.path,
      '--project',
      app.path,
      if (dryRun) '--dry-run',
      if (force) '--force',
    ];
    return runner.runCapturing(args);
  }

  /// Reads the raw corpus manifest JSON written under the app root (the
  /// machine-readable #628 batch-driving contract).
  Map<String, dynamic> readManifestJson() =>
      jsonDecode(
            File(
              p.join(app.path, '.zfa', 'manifests', 'corpus-manifest.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('U16 (FR-001): import arg surface', () {
    test('exposes --dry-run, --force and --project, with a source', () {
      final cmd = CorpusImportCommand();
      expect(cmd.name, equals('import'));
      expect(cmd.argParser.options, contains('dry-run'));
      expect(cmd.argParser.options, contains('force'));
      expect(cmd.argParser.options, contains('project'));
    });

    test(
      'import without a source is a usage error naming the source',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'corpus',
          'import',
          '--project',
          app.path,
        ]);
        expect(out, contains('source'));
        expect(out, contains('required'));
      },
    );
  });

  group('U17 (FR-001): invalid source', () {
    test('fails with a message, not a crash', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'corpus',
        'import',
        p.join(app.path, 'no-such-corpus'),
        '--project',
        app.path,
      ]);
      expect(out, contains('❌'));
      expect(out, contains('not found'));
      // No stack trace without --verbose.
      expect(out, isNot(contains('Stack trace')));
    });
  });

  group('U18 (FR-001): registration', () {
    test('corpus is registered in the CLI runner (help lists it)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final help = await runner.runCapturing([]);
      expect(help, contains('corpus'));

      // And the command family dispatches its usage.
      final out = await runner.runCapturing(['corpus']);
      expect(out, contains('import'));
    });
  });

  /// Sha256 hex of [content] — the report's divergence currency.
  String sha256Of(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  group('A4 (US2.AC1): re-import after corpus growth', () {
    test('touches only the new features — old specs and tdd/ evidence stay '
        'put, manifest reflects the new total', () async {
      await importCorpus();
      // Simulate loop progress on an imported feature.
      File(
        p.join(app.path, 'specs', '001-clean', 'tdd', 'test-list.md'),
      ).writeAsStringSync('# loop evidence\n');
      final oldSpec = File(
        p.join(app.path, 'specs', '001-clean', 'spec.md'),
      ).readAsStringSync();

      corpus.grow(); // +011-growth-a, +012-growth-b
      final out = await importCorpus();

      // Old features report skipped; new ones imported.
      expect(out, contains('001-clean: skipped'));
      expect(out, contains('002-no-scenarios: skipped not-ready'));
      expect(out, contains('011-growth-a: imported'));
      expect(out, contains('012-growth-b: imported'));

      // Old spec content untouched.
      expect(
        File(
          p.join(app.path, 'specs', '001-clean', 'spec.md'),
        ).readAsStringSync(),
        equals(oldSpec),
      );
      // Old loop evidence untouched.
      expect(
        File(
          p.join(app.path, 'specs', '001-clean', 'tdd', 'test-list.md'),
        ).readAsStringSync(),
        equals('# loop evidence\n'),
      );

      // The manifest reflects the new total, in order.
      final manifest = readManifestJson();
      expect(
        (manifest['features'] as List).map((f) => (f as Map)['name']),
        equals([
          '001-clean',
          '002-no-scenarios',
          '003-speckit',
          '011-growth-a',
          '012-growth-b',
        ]),
      );
    });
  });

  group('A5 (US2.AC2): tdd/ immutability', () {
    test('re-import leaves existing tdd/ trees byte-identical '
        '(checksum-verified)', () async {
      await importCorpus();
      // Loop progress: a test list, a cycle log, an artifact.
      final tddDir = Directory(
        p.join(app.path, 'specs', '002-no-scenarios', 'tdd'),
      );
      File(
        p.join(tddDir.path, 'test-list.md'),
      ).writeAsStringSync('# Test List (imported-then-driven)\n');
      File(
        p.join(tddDir.path, 'cycle-log.md'),
      ).writeAsStringSync('# Cycle Log\n## Cycle 1\n');
      Directory(p.join(tddDir.path, 'artifacts')).createSync();
      File(
        p.join(tddDir.path, 'artifacts', 'red.txt'),
      ).writeAsStringSync('red evidence\n');

      Map<String, String> checksums(Directory root) => {
        for (final entity in root.listSync(recursive: true))
          if (entity is File)
            p.relative(entity.path, from: app.path): sha256
                .convert(entity.readAsBytesSync())
                .toString(),
      };
      final before = checksums(tddDir);

      final out = await importCorpus(); // re-import

      // The re-import must complete (not fail) for the immutability
      // claim to mean anything.
      expect(out, isNot(contains('❌')), reason: out);
      expect(out, contains('002-no-scenarios: skipped'));
      expect(checksums(tddDir), equals(before));
    });
  });

  group('A6 (US2.AC3): divergence', () {
    test('a divergent spec is kept by default with both hashes reported; '
        '--force updates it', () async {
      await importCorpus();
      final imported = File(
        p.join(app.path, 'specs', '001-clean', 'spec.md'),
      ).readAsStringSync();

      // The source spec changes upstream.
      final changed = FixtureCorpus.cleanSpec('001-clean-v2');
      corpus.editSpec('001-clean', changed);

      // Default: keep the imported copy, report both hashes.
      final out = await importCorpus();
      expect(out, contains('001-clean: divergent'));
      expect(out, contains(sha256Of(changed)));
      expect(out, contains(sha256Of(imported)));
      expect(
        File(
          p.join(app.path, 'specs', '001-clean', 'spec.md'),
        ).readAsStringSync(),
        equals(imported),
        reason: 'divergent target must be kept by default',
      );

      // --force: the source content replaces the imported copy.
      final forced = await importCorpus(force: true);
      expect(forced, contains('001-clean: imported'));
      expect(
        File(
          p.join(app.path, 'specs', '001-clean', 'spec.md'),
        ).readAsStringSync(),
        equals(changed),
        reason: '--force must update the divergent spec',
      );
    });
  });

  group('A7 (US3.AC1): manifest readiness marks', () {
    test(
      'manifest marks every feature ready/not-ready with a one-line reason',
      () async {
        await importCorpus();

        final features = readManifestJson()['features'] as List;
        expect(features, hasLength(3));
        for (final f in features) {
          final m = f as Map;
          expect(m['ready'], isA<bool>(), reason: '$m');
          final reason = m['reason'] as String;
          if (m['ready'] == true) {
            expect(reason, isEmpty, reason: 'ready features carry no reason');
          } else {
            expect(reason, isNotEmpty);
            expect(
              reason.contains('\n'),
              isFalse,
              reason: 'the reason must be one line',
            );
          }
        }

        // The fixture's pinned marks.
        final byName = {
          for (final f in features) (f as Map)['name'] as String: f,
        };
        expect(byName['001-clean']!['ready'], isTrue);
        expect(byName['003-speckit']!['ready'], isTrue);
        expect(byName['002-no-scenarios']!['ready'], isFalse);
        expect(
          byName['002-no-scenarios']!['reason'] as String,
          equals('no acceptance scenarios'),
        );
      },
    );
  });

  group('A8 (US3.AC2): the manifest mark is the consumer contract', () {
    test('a consumer (batch driving, #628) can rely on the manifest mark '
        'without re-deriving it', () async {
      await importCorpus();

      // Simulate #628's batch driver: every decision comes from the
      // manifest JSON alone — no spec re-parsing, no SpecParser call.
      final manifest = readManifestJson();
      final features = manifest['features'] as List;
      final drivable = [
        for (final f in features)
          if ((f as Map)['ready'] == true) f['name'] as String,
      ];
      final blocked = [
        for (final f in features)
          if ((f as Map)['ready'] != true) '${f['name']}: ${f['reason']}',
      ];

      expect(drivable, equals(['001-clean', '003-speckit']));
      expect(blocked, equals(['002-no-scenarios: no acceptance scenarios']));
    });
  });

  group('A3 (US1.AC3): not-loop-ready specs', () {
    test('a no-scenario feature is imported verbatim AND reported not-ready '
        '(never dropped, never mutated)', () async {
      final out = await importCorpus();

      // Imported anyway — the spec exists under the app's specs/ tree,
      // byte-for-byte (never dropped).
      final spec = File(
        p.join(app.path, 'specs', '002-no-scenarios', 'spec.md'),
      );
      expect(
        spec.existsSync(),
        isTrue,
        reason: 'not-ready feature must still be imported\nCLI output:\n$out',
      );
      expect(
        spec.readAsStringSync(),
        equals(FixtureCorpus.proseOnlySpec('002-no-scenarios')),
        reason: 'spec content must be copied verbatim, never mutated',
      );

      // Reported — the CLI names the feature and its not-ready reason.
      expect(out, contains('002-no-scenarios'));
      expect(out, contains('not-ready'));
      expect(out, contains('no acceptance scenarios'));

      // The manifest carries the mark with a reason (US3's consumer
      // contract).
      final notReady =
          (readManifestJson()['features'] as List)
                  .where((f) => (f as Map)['name'] == '002-no-scenarios')
                  .single
              as Map;
      expect(notReady['ready'], isFalse);
      expect(notReady['reason'] as String, contains('no acceptance'));
    });
  });

  group('A2 (US1.AC2): loop-plannability after import', () {
    test(
      'every ready imported feature plans via `zfa tdd plan` with zero manual '
      'edits, and the not-ready one refuses with the manifest\'s reason',
      () async {
        await importCorpus();

        // The ready feature: plan succeeds with no manual file edits (the
        // spec content was copied verbatim; the only structural addition
        // import made was the tdd/ directory).
        final planRunner = CliRunner(exitOnCompletion: false);
        final planOut = await planRunner.runCapturing([
          'tdd',
          'plan',
          '001-clean',
          '--project',
          app.path,
        ]);
        final readyList = File(
          p.join(app.path, 'specs', '001-clean', 'tdd', 'test-list.md'),
        );
        expect(
          readyList.existsSync(),
          isTrue,
          reason: 'plan did not write a test list\nCLI output:\n$planOut',
        );
        expect(readyList.readAsStringSync(), contains('| A1 |'));

        // The not-ready feature: plan refuses — no test list is written,
        // the CLI reports the failure instead of crashing.
        final refuseOut = await planRunner.runCapturing([
          'tdd',
          'plan',
          '002-no-scenarios',
          '--project',
          app.path,
        ]);
        expect(refuseOut, contains('❌'));
        expect(
          File(
            p.join(
              app.path,
              'specs',
              '002-no-scenarios',
              'tdd',
              'test-list.md',
            ),
          ).existsSync(),
          isFalse,
          reason: 'plan must not write a list for a not-ready feature',
        );

        // The refusal's reason matches the manifest's reason: the
        // plan-equivalent parser (the exact SpecParser entry point
        // `zfa tdd plan` uses) refuses 002 with the same reason the
        // manifest carries.
        final manifest = readManifestJson();
        final notReady =
            (manifest['features'] as List)
                    .where((f) => (f as Map)['name'] == '002-no-scenarios')
                    .single
                as Map;
        expect(notReady['ready'], isFalse);
        final reason = notReady['reason'] as String;
        expect(reason, isNotEmpty);
        final specMd = File(
          p.join(app.path, 'specs', '002-no-scenarios', 'spec.md'),
        ).readAsStringSync();
        expect(
          () => const SpecParser().parse('002-no-scenarios', specMd),
          throwsStateError,
        );
        try {
          const SpecParser().parse('002-no-scenarios', specMd);
        } on StateError catch (e) {
          expect(e.message, contains(reason));
        }
      },
    );
  });

  group('A1 (US1.AC1): N-feature corpus import', () {
    test('copies every spec.md, creates per-feature tdd/ dirs, and lists all N '
        'features deterministically in the manifest', () async {
      final out = await importCorpus();

      for (final name in FixtureCorpus.featureNames) {
        final spec = File(p.join(app.path, 'specs', name, 'spec.md'));
        expect(
          spec.existsSync(),
          isTrue,
          reason: 'missing $spec\nCLI output:\n$out',
        );
        expect(
          Directory(p.join(app.path, 'specs', name, 'tdd')).existsSync(),
          isTrue,
          reason: 'missing tdd/ for $name\nCLI output:\n$out',
        );
      }

      // The manifest is machine-readable and lists all N features in
      // deterministic (lexicographic source) order — the #628 contract.
      final manifest = readManifestJson();
      final featureNames = (manifest['features'] as List)
          .map((f) => (f as Map)['name'] as String)
          .toList();
      expect(
        featureNames,
        equals(FixtureCorpus.featureNames),
        reason: 'manifest features out of order: $featureNames',
      );
      expect(manifest['source_corpus'], equals(corpus.root.path));
    });
  });
}
