// Tests for CorpusCommand (spec 051, U27-U34).
//
// Tests the `corpus run`, `corpus audit`, and `corpus status` subcommands
// using in-memory/temp-dir fixtures with the --project flag.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_feature_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_progress_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/models/gap_ledger_entry.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('corpus_cmd_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  /// Create a minimal corpus manifest for testing.
  Future<void> createManifest({
    List<Map<String, dynamic>>? features,
  }) async {
    final manifestDir = Directory(p.join(tmpDir.path, '.zfa', 'manifests'));
    await manifestDir.create(recursive: true);
    final manifestFile = File(p.join(manifestDir.path, 'corpus-manifest.json'));
    final manifest = {
      'source_corpus': '/tmp/corpus',
      'imported_at': '2026-08-31T12:00:00Z',
      'features': features ?? [
        {'name': '001-ready', 'ready': true, 'reason': ''},
        {'name': '002-not-ready', 'ready': false, 'reason': 'no acceptance scenarios'},
      ],
    };
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
  }

  group('corpus status', () {
    test('[A10] [A11] reports per-state counts and resume point', () async {
      await createManifest();
      final store = CorpusProgressStore(tmpDir.path);
      await store.save(CorpusProgress(
        features: {
          '001-ready': const CorpusFeatureProgress(
            name: '001-ready',
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ),
          '002-not-ready': const CorpusFeatureProgress(
            name: '002-not-ready',
            state: CorpusFeatureState.notReady,
          ),
        },
      ));

      // Run status via Process.run.
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, 0, reason: 'All features done → exit 0');
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('corpus status: 001-ready done'));
      expect(output, contains('corpus status: 002-not-ready not-ready'));
      expect(output, contains('done=1'));
      expect(output, contains('not_ready=1'));
    });

    test('[A11] exit non-zero when features are pending', () async {
      await createManifest();
      // No progress file → all features are pending.

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, isNot(0), reason: 'Pending features → non-zero');
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('pending=2'));
    });

    test('[U32] status summary line matches contract format', () async {
      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
      ]);
      final store = CorpusProgressStore(tmpDir.path);
      await store.save(CorpusProgress(
        features: {
          '001': const CorpusFeatureProgress(
            name: '001',
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ),
        },
      ));

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      // Summary line should match: corpus status: done=<n> stopped=<n> ...
      final summaryLine = output.split('\n').where(
        (l) => l.startsWith('corpus status: done='),
      ).firstOrNull;
      expect(summaryLine, isNotNull, reason: 'Summary line present');
      expect(summaryLine, contains('total=1'));
      expect(summaryLine, contains('resume=none'));
    });

    test('[U33] exit 0 when all features done+gated', () async {
      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
      ]);
      final store = CorpusProgressStore(tmpDir.path);
      await store.save(CorpusProgress(
        features: {
          '001': const CorpusFeatureProgress(
            name: '001',
            state: CorpusFeatureState.done,
            gateOutcome: 'PASS',
          ),
        },
      ));

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, 0);
    });

    test('[U5] [U6] resume point identifies first non-done feature', () async {
      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
        {'name': '002', 'ready': true, 'reason': ''},
        {'name': '003', 'ready': true, 'reason': ''},
      ]);
      final store = CorpusProgressStore(tmpDir.path);
      await store.save(CorpusProgress(
        features: {
          '001': const CorpusFeatureProgress(
            name: '001',
            state: CorpusFeatureState.done,
          ),
          '002': const CorpusFeatureProgress(
            name: '002',
            state: CorpusFeatureState.stopped,
          ),
        },
      ));

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('resume=002'));
    });
  });

  group('corpus audit', () {
    test('[A7] attributes lib/ files from cycle-log entries', () async {
      // Create a minimal lib/ structure.
      final libDir = Directory(p.join(tmpDir.path, 'lib', 'src'));
      await libDir.create(recursive: true);
      await File(p.join(libDir.path, 'main.dart')).writeAsString('void main() {}');

      // Create a cycle log that references the file.
      final specsDir = Directory(p.join(tmpDir.path, 'specs', '001-ready', 'tdd'));
      await specsDir.create(recursive: true);
      await File(p.join(specsDir.path, 'cycle-log.md')).writeAsString(
        '## Cycle 1\n- green: generated lib/src/main.dart via zfa make',
      );

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('corpus audit: attributed='));
      expect(output, contains('total='));
    });

    test('[A8] exits non-zero when unattributed files exist', () async {
      // Create lib/ with a file that has no provenance.
      final libDir = Directory(p.join(tmpDir.path, 'lib'));
      await libDir.create(recursive: true);
      await File(p.join(libDir.path, 'mystery.dart')).writeAsString('void main() {}');

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('UNATTRIBUTED'));
    });
  });

  group('corpus run', () {
    test('[U28] [U29] summary line matches contract format', () async {
      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
      ]);
      // No progress file → fresh run.

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'run', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      // Summary line should match: corpus run: done=<n> ...
      final summaryLine = output.split('\n').where(
        (l) => l.startsWith('corpus run: done='),
      ).firstOrNull;
      expect(summaryLine, isNotNull, reason: 'Summary line present');
      expect(summaryLine, contains('total=1'));
    });

    test('[A12] refuses concurrent run via in-flight marker', () async {
      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
      ]);
      final store = CorpusProgressStore(tmpDir.path);
      // Set in-flight with a live pid (use current process pid).
      await store.save(CorpusProgress(
        inFlight: true,
        ownerPid: pid,
      ));

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'run', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, 4, reason: 'Concurrent run refused → exit 4');
      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('corpus run is already in flight'));
    });

    test('[U18] skips not-ready features', () async {
      await createManifest(features: [
        {'name': '001', 'ready': false, 'reason': 'no scenarios'},
      ]);

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'run', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('skipped (not-ready)'));
      expect(result.exitCode, 0, reason: 'Only not-ready features → exit 0');
    });

    test('[A6] explicit waiver visible in corpus progress and final report', () async {
      // Pre-set a feature with a waiver record.
      final store = CorpusProgressStore(tmpDir.path);
      await store.save(CorpusProgress(
        features: {
          '001-waived': const CorpusFeatureProgress(
            name: '001-waived',
            state: CorpusFeatureState.waived,
            waived: WaiverRecord(
              reason: 'mutation tool unavailable in CI',
              actor: 'maintainer',
              when: '2026-08-31T10:00:00Z',
            ),
          ),
        },
      ));

      await createManifest(features: [
        {'name': '001-waived', 'ready': true, 'reason': ''},
      ]);

      // Run status to see waiver in output.
      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'status', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('waived (reason="mutation tool unavailable in CI")'));
      expect(output, contains('waived=1'));
      // Waiver makes the feature count as done for exit code.
      expect(result.exitCode, 0);
    });
  });

  group('corpus audit', () {
    test('[A9] removing carve-out makes file unattributed and audit fails', () async {
      // Create a lib/ file that will be a carve-out.
      final libDir = Directory(p.join(tmpDir.path, 'lib'));
      await libDir.create(recursive: true);
      await File(p.join(libDir.path, 'manual_ui.dart')).writeAsString('void main() {}');

      // Create carve-out manifest with the file.
      final carveOutDir = Directory(p.join(tmpDir.path, '.zfa', 'corpus'));
      await carveOutDir.create(recursive: true);
      await File(p.join(carveOutDir.path, 'carve-out.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'entries': [
            {
              'path': 'lib/manual_ui.dart',
              'reason': 'manual UI widget',
              'added_by': 'maintainer',
              'added_at': '2026-08-31T10:00:00Z',
            },
          ],
        }),
      );

      // First audit: should pass (file attributed via carve-out).
      var result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, 0, reason: 'Carve-out attributed → exit 0');
      var output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('corpus audit: lib/manual_ui.dart attributed (carve-out'));

      // Remove the carve-out entry.
      await File(p.join(carveOutDir.path, 'carve-out.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({'entries': []}),
      );

      // Second audit: should fail (file now unattributed).
      result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      expect(result.exitCode, isNot(0), reason: 'Removed carve-out → unattributed → exit non-zero');
      output = '${result.stdout}\n${result.stderr}';
      expect(output, contains('corpus audit: lib/manual_ui.dart UNATTRIBUTED'));
    });
  });

  group('U27 U30 U31 format contracts', () {
    test('[U27] corpus run per-feature progress lines match contract format', () async {
      final passBin = File(p.join(tmpDir.path, 'pass_bin.dart'));
      await passBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  print('run: feature=test result=complete');
  exit(0);
}
''');

      await createManifest(features: [
        {'name': '001', 'ready': true, 'reason': ''},
        {'name': '002', 'ready': false, 'reason': 'not ready'},
      ]);

      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          'run', 'bin/zfa.dart', 'tdd', 'corpus', 'run',
          '--project', tmpDir.path,
          '--zfa-bin', passBin.path,
        ],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      // Contract: "corpus run: <name> -> <state>"
      expect(output, matches(RegExp(r'corpus run: 001 -> done \(gate=PASS\)')));
      expect(output, matches(RegExp(r'corpus run: 002 -> skipped \(not-ready\)')));
    });

    test('[U30] corpus audit per-file report lines match contract format', () async {
      final libDir = Directory(p.join(tmpDir.path, 'lib', 'src'));
      await libDir.create(recursive: true);
      await File(p.join(libDir.path, 'attributed.dart')).writeAsString('void main() {}');
      await File(p.join(libDir.path, 'mystery.dart')).writeAsString('void main() {}');

      // Create a cycle-log that attributes one file.
      final specsDir = Directory(p.join(tmpDir.path, 'specs', 'feat', 'tdd'));
      await specsDir.create(recursive: true);
      await File(p.join(specsDir.path, 'cycle-log.md')).writeAsString(
        '## Cycle 1\n- green: generated lib/src/attributed.dart via zfa make',
      );

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      // Contract: "corpus audit: <path> attributed (<source>: <invocation>)"
      expect(output, matches(RegExp(
        r'corpus audit: lib/src/attributed\.dart attributed \(cycleLog: .+\)',
      )));
      // Contract: "corpus audit: <path> UNATTRIBUTED"
      expect(output, matches(RegExp(
        r'corpus audit: lib/src/mystery\.dart UNATTRIBUTED',
      )));
    });

    test('[U31] corpus audit summary line matches machine-readable contract', () async {
      final libDir = Directory(p.join(tmpDir.path, 'lib', 'src'));
      await libDir.create(recursive: true);
      await File(p.join(libDir.path, 'one.dart')).writeAsString('void main() {}');
      await File(p.join(libDir.path, 'two.dart')).writeAsString('void main() {}');

      // Attribute one via cycle-log.
      final specsDir = Directory(p.join(tmpDir.path, 'specs', 'feat', 'tdd'));
      await specsDir.create(recursive: true);
      await File(p.join(specsDir.path, 'cycle-log.md')).writeAsString(
        '## Cycle 1\n- green: generated lib/src/one.dart via zfa make',
      );

      final result = await Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/zfa.dart', 'tdd', 'corpus', 'audit', '--project', tmpDir.path],
        workingDirectory: '/Users/ahmettok/Developer/zuraffa',
      );

      final output = '${result.stdout}\n${result.stderr}';
      // Contract: "corpus audit: attributed=<n> carve-out=<n> unattributed=<n> total=<n>"
      final summaryLine = output.split('\n').where(
        (l) => l.startsWith('corpus audit: attributed='),
      ).firstOrNull;
      expect(summaryLine, isNotNull, reason: 'Summary line present');
      expect(summaryLine, matches(RegExp(
        r'corpus audit: attributed=\d+ carve-out=\d+ unattributed=\d+ total=\d+',
      )));
      // Verify actual counts: 1 attributed, 0 carve-out, 1 unattributed, 2 total.
      expect(summaryLine, contains('attributed=1'));
      expect(summaryLine, contains('carve-out=0'));
      expect(summaryLine, contains('unattributed=1'));
      expect(summaryLine, contains('total=2'));
    });
  });
}
