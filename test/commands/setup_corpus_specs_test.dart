// `zfa setup --specs <dir>` wiring tests (spec 050-corpus-import,
// tasks T015; behaviors U19-U20, traced to FR-001).
//
// Drives the real CLI entry point in dry-run mode so the whole setup
// flow (create → deps → structure → config → TDD baseline → corpus
// import → summary) runs without subprocesses or network — the corpus
// import itself is pure file I/O through the shared CorpusImporter.
// Fast tier: no `slow` tag.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

import '../cli/services/helpers/fixture_corpus.dart';

void main() {
  late FixtureCorpus corpus;
  late Directory workDir;

  setUp(() {
    corpus = FixtureCorpus.create();
    workDir = Directory.systemTemp.createTempSync('zfa_setup_specs_');
  });

  tearDown(() {
    corpus.dispose();
    if (workDir.existsSync()) workDir.deleteSync(recursive: true);
  });

  /// Runs `zfa setup <name> --dart ... ` scoped to the temp workdir.
  Future<String> runSetup({String? specs, bool dryRun = true}) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      '-C',
      workDir.path,
      'setup',
      'demo_app',
      '--dart',
      '--no-git',
      if (dryRun) '--dry-run',
      if (specs != null) ...['--specs', specs],
    ]);
  }

  group('U19 (FR-001): --specs triggers the import step', () {
    test('the corpus import runs after the TDD baseline step, with 8-step '
        'numbering when present', () async {
      final out = await runSetup(specs: corpus.root.path);

      // The import step is numbered 7 of 8 and runs after the
      // TDD-baseline step (6 of 8) and before the summary (8 of 8).
      final baselineIdx = out.indexOf('[6/8]');
      final importIdx = out.indexOf('[7/8]');
      final summaryIdx = out.indexOf('[8/8]');
      expect(baselineIdx, greaterThanOrEqualTo(0), reason: out);
      expect(importIdx, greaterThan(baselineIdx), reason: out);
      expect(summaryIdx, greaterThan(importIdx), reason: out);
      expect(out, contains('Importing spec corpus'));

      // The shared importer's report is printed (dry-run prefixed —
      // setup --dry-run must not write the corpus into the app).
      expect(out, contains('[dry-run] 001-clean: imported'));
      expect(out, contains('not-ready'));
      expect(RegExp(r'\[\d+/8\]').allMatches(out), isNotEmpty);
      expect(RegExp(r'\[\d+/(?!8\d*\])').hasMatch(out), isFalse);
    });

    test('exposes the --specs option', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('specs'));
    });
  });

  group('U20 (FR-001): setup without --specs is unchanged', () {
    test(
      'no corpus import step, legacy 7-step numbering, no corpus output',
      () async {
        final out = await runSetup();

        expect(out, contains('[7/7]'));
        expect(out, isNot(contains('[7/8]')));
        expect(out, isNot(contains('[8/8]')));
        expect(out, isNot(contains('Importing spec corpus')));
        expect(out, isNot(contains('corpus-manifest')));
        expect(RegExp(r'\[\d+/7\]').allMatches(out), isNotEmpty);
        expect(RegExp(r'\[\d+/(?!7\d*\])').hasMatch(out), isFalse);
      },
    );

    test('rejects an invalid corpus before creating the app', () async {
      final missing = '${workDir.path}/missing-corpus';

      final out = await runSetup(specs: missing);
      expect(out, contains('source corpus not found'));
      expect(Directory('${workDir.path}/demo_app').existsSync(), isFalse);
    });
  });
}
