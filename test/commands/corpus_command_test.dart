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
