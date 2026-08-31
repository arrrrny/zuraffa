// Tests for CorpusRunner (spec 051, U12-U21).
//
// Uses a fake zfa binary to simulate run/verify outcomes.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/corpus_feature_progress.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_progress_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/corpus_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/models/gap_ledger_entry.dart';

void main() {
  late Directory tmpDir;
  late Directory projectDir;
  late File fakeZfaBin;
  late CorpusProgressStore store;
  late GapLedger ledger;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('corpus_runner_test_');
    projectDir = Directory(p.join(tmpDir.path, 'project'));
    await projectDir.create(recursive: true);

    // Create a fake zfa binary that always succeeds.
    fakeZfaBin = File(p.join(tmpDir.path, 'fake_zfa.dart'));
    await fakeZfaBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  // tdd run — always succeeds. Args: <script> tdd run <feature> --project <dir>
  // When running 'dart <script> tdd run <feature>', args = ['tdd', 'run', '<feature>', ...]
  final feature = args.length > 2 ? args[2] : 'unknown';
  print('run: feature=\$feature result=complete pending=0 red=0 green=0 done=3');
  exit(0);
}
''');

    store = CorpusProgressStore(
      projectDir.path,
      pidAlive: (pid) => false,
    );
    ledger = GapLedger(projectDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('CorpusRunner', () {
    test('[U12] drives a ready feature through run then verify', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-ready'],
        readiness: {'001-ready': true},
      );

      expect(outcomes.length, 1);
      expect(outcomes.first.name, '001-ready');
      expect(outcomes.first.state, CorpusFeatureState.done);
      expect(outcomes.first.gateOutcome, 'PASS');
    });

    test('[U13] feature run failure stops corpus and appends ledger', () async {
      // Create a zfa that fails on run.
      final failBin = File(p.join(tmpDir.path, 'fail_zfa.dart'));
      await failBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  // tdd run — fails.
  stderr.writeln('Error: zfa make failed');
  exit(1);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: failBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-fail', '002-later'],
        readiness: {
          '001-fail': true,
          '002-later': true,
        },
      );

      expect(outcomes.length, 1, reason: 'Only first feature attempted');
      expect(outcomes.first.state, CorpusFeatureState.stopped);
      expect(outcomes.first.stoppedAt, 'run');

      // Verify ledger entry.
      final entries = await ledger.load();
      expect(entries.length, 1);
      expect(entries.first.feature, '001-fail');
      expect(entries.first.outcome, 'stopped');

      // Verify 002-later was NOT started.
      final progress = await store.load();
      expect(progress!.features.containsKey('002-later'), false);
    });

    test('[U14] verify gate PASS marks feature done', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001'],
        readiness: {'001': true},
      );

      expect(outcomes.first.state, CorpusFeatureState.done);
      expect(outcomes.first.gateOutcome, 'PASS');
    });

    test('[U15] verify gate NOT_ASSESSED stops with ledger entry', () async {
      final notAssessedBin = File(p.join(tmpDir.path, 'notassessed_zfa.dart'));
      await notAssessedBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=NOT_ASSESSED killed=0 survived=0 timed_out=0 mutation_was_run=false');
    exit(1);
  }
  print('run: feature=test result=complete pending=0 red=0 green=0 done=3');
  exit(0);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: notAssessedBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001'],
        readiness: {'001': true},
      );

      expect(outcomes.first.state, CorpusFeatureState.stopped);
      expect(outcomes.first.stoppedAt, 'verify');

      final entries = await ledger.load();
      expect(entries.length, 1);
      expect(entries.first.outcome, 'NOT_ASSESSED');
    });

    test('[U16] verify gate FAIL_SURVIVED stops with ledger entry', () async {
      final survivedBin = File(p.join(tmpDir.path, 'survived_zfa.dart'));
      await survivedBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=FAIL_SURVIVED killed=3 survived=2 timed_out=0 mutation_was_run=true');
    exit(1);
  }
  print('run: feature=test result=complete pending=0 red=0 green=0 done=3');
  exit(0);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: survivedBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001'],
        readiness: {'001': true},
      );

      expect(outcomes.first.state, CorpusFeatureState.stopped);
      expect(outcomes.first.gateOutcome, 'FAIL_SURVIVED');

      final entries = await ledger.load();
      expect(entries.first.outcome, 'FAIL_SURVIVED');
    });

    test('[U18] not-ready features are skipped and reported', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-ready', '002-not-ready'],
        readiness: {
          '001-ready': true,
          '002-not-ready': false,
        },
      );

      expect(outcomes.length, 2);
      expect(outcomes[0].state, CorpusFeatureState.done);
      expect(outcomes[1].state, CorpusFeatureState.notReady);
    });

    test('[U19] corpus-level stop halts whole run', () async {
      final failBin = File(p.join(tmpDir.path, 'fail_zfa.dart'));
      await failBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  stderr.writeln('Error');
  exit(1);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: failBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001', '002', '003'],
        readiness: {'001': true, '002': true, '003': true},
      );

      // Only first feature attempted (it failed).
      expect(outcomes.length, 1);
      expect(outcomes.first.state, CorpusFeatureState.stopped);
    });

    test('[U20] persists corpus progress after every feature', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      await runner.run(
        manifestFeatures: ['001', '002'],
        readiness: {'001': true, '002': true},
      );

      final progress = await store.load();
      expect(progress, isNotNull);
      expect(progress!.features['001']?.state, CorpusFeatureState.done);
      expect(progress.features['002']?.state, CorpusFeatureState.done);
    });

    test('[U17] waived feature skips gate failure and marks done with waiver record', () async {
      // Pre-set a feature with a waiver record in progress.
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

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-waived'],
        readiness: {'001-waived': true},
      );

      // The waived feature should be skipped, not re-driven.
      expect(outcomes.length, 1);
      expect(outcomes.first.name, '001-waived');
      expect(outcomes.first.state, CorpusFeatureState.waived);

      // Waiver record preserved.
      final progress = await store.load();
      expect(progress!.features['001-waived']?.waived?.reason,
          'mutation tool unavailable in CI');
    });

    test('[U21] resumes from first incomplete feature', () async {
      // First run: fails on 002 (run step).
      final failOn002Bin = File(p.join(tmpDir.path, 'fail002_zfa.dart'));
      await failOn002Bin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  // When running 'dart <script> tdd run <feature>', args = ['tdd', 'run', '<feature>', ...]
  final feature = args.length > 2 ? args[2] : 'unknown';
  if (feature == '002') {
    stderr.writeln('Error on 002');
    exit(1);
  }
  print('run: feature=\$feature result=complete pending=0 red=0 green=0 done=3');
  exit(0);
}
''');

      var runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: failOn002Bin.path,
      );

      var outcomes = await runner.run(
        manifestFeatures: ['001', '002'],
        readiness: {'001': true, '002': true},
      );

      // Runner returns both outcomes: 001 done, 002 stopped.
      expect(outcomes.length, 2, reason: 'Both features have outcomes');
      expect(outcomes[0].state, CorpusFeatureState.done); // 001 done
      expect(outcomes[1].state, CorpusFeatureState.stopped); // 002 stopped
      expect(outcomes[1].stoppedAt, 'run');

      // Verify 002 is stopped in progress.
      var progress = await store.load();
      expect(progress!.features['002']?.state, CorpusFeatureState.stopped);

      // Second run: should skip 001 (done), retry 002 (now passes).
      final passAllBin = File(p.join(tmpDir.path, 'passall_zfa.dart'));
      await passAllBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  print('run: feature=test result=complete pending=0 red=0 green=0 done=3');
  exit(0);
}
''');

      runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: passAllBin.path,
      );

      outcomes = await runner.run(
        manifestFeatures: ['001', '002'],
        readiness: {'001': true, '002': true},
      );

      // 001 skipped (already done), only 002 attempted and succeeds.
      expect(outcomes.length, 2);
      expect(outcomes[0].state, CorpusFeatureState.done); // 001 skipped
      expect(outcomes[1].state, CorpusFeatureState.done); // 002 now done

      // Resolution entry in ledger.
      final entries = await ledger.load();
      final resolutions = entries.where((e) => e.resolution == 'resolved');
      expect(resolutions.length, 1);
      expect(resolutions.first.feature, '002');
    });
  });

  group('acceptance-level (A1-A5 via CorpusRunner)', () {
    test('[A1] drives each ready feature in manifest order, persists progress', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-alpha', '002-beta', '003-not-ready'],
        readiness: {
          '001-alpha': true,
          '002-beta': true,
          '003-not-ready': false,
        },
      );

      expect(outcomes.length, 3);
      expect(outcomes[0].name, '001-alpha');
      expect(outcomes[0].state, CorpusFeatureState.done);
      expect(outcomes[0].gateOutcome, 'PASS');
      expect(outcomes[1].name, '002-beta');
      expect(outcomes[1].state, CorpusFeatureState.done);
      expect(outcomes[1].gateOutcome, 'PASS');
      expect(outcomes[2].name, '003-not-ready');
      expect(outcomes[2].state, CorpusFeatureState.notReady);

      // Progress persisted after each feature.
      final progress = await store.load();
      expect(progress, isNotNull);
      expect(progress!.features['001-alpha']?.state, CorpusFeatureState.done);
      expect(progress.features['002-beta']?.state, CorpusFeatureState.done);
      expect(progress.features['003-not-ready']?.state, CorpusFeatureState.notReady);
    });

    test('[A2] resumes from k+1 after interruption', () async {
      // First run: fails on 002.
      final failOn002 = File(p.join(tmpDir.path, 'fail002.dart'));
      await failOn002.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  final feature = args.length > 2 ? args[2] : 'unknown';
  if (feature == '002') {
    stderr.writeln('Error on 002');
    exit(1);
  }
  print('run: feature=\$feature result=complete');
  exit(0);
}
''');

      var runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: failOn002.path,
      );

      var outcomes = await runner.run(
        manifestFeatures: ['001', '002', '003'],
        readiness: {'001': true, '002': true, '003': true},
      );

      // 001 done, 002 stopped.
      expect(outcomes.length, 2);
      expect(outcomes[0].state, CorpusFeatureState.done);
      expect(outcomes[1].state, CorpusFeatureState.stopped);

      // Second run: 001 skipped, 002 and 003 succeed.
      final passAll = File(p.join(tmpDir.path, 'pass_all.dart'));
      await passAll.writeAsString('''
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

      runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: passAll.path,
      );

      outcomes = await runner.run(
        manifestFeatures: ['001', '002', '003'],
        readiness: {'001': true, '002': true, '003': true},
      );

      // 001 skipped (done), 002 retried and done, 003 done.
      expect(outcomes.length, 3);
      expect(outcomes[0].state, CorpusFeatureState.done);
      expect(outcomes[1].state, CorpusFeatureState.done);
      expect(outcomes[2].state, CorpusFeatureState.done);
    });

    test('[A3] stops non-zero on failure, appends ledger, does not start later features', () async {
      final failBin = File(p.join(tmpDir.path, 'fail_run.dart'));
      await failBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=PASS killed=5 survived=0 timed_out=0 mutation_was_run=true');
    exit(0);
  }
  stderr.writeln('Build error');
  exit(1);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: failBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-fail', '002-later'],
        readiness: {'001-fail': true, '002-later': true},
      );

      // Only first feature attempted.
      expect(outcomes.length, 1);
      expect(outcomes.first.name, '001-fail');
      expect(outcomes.first.state, CorpusFeatureState.stopped);

      // 002-later was NOT started.
      final progress = await store.load();
      expect(progress!.features.containsKey('002-later'), false);

      // Ledger entry appended.
      final entries = await ledger.load();
      expect(entries.length, 1);
      expect(entries.first.feature, '001-fail');
      expect(entries.first.outcome, 'stopped');
    });

    test('[A4] passing verify gate marks feature done with gate recorded', () async {
      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: fakeZfaBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001'],
        readiness: {'001': true},
      );

      expect(outcomes.length, 1);
      expect(outcomes.first.state, CorpusFeatureState.done);
      expect(outcomes.first.gateOutcome, 'PASS');

      // Progress shows done with gate.
      final progress = await store.load();
      expect(progress!.features['001']?.state, CorpusFeatureState.done);
      expect(progress.features['001']?.gateOutcome, 'PASS');
    });

    test('[A5] NOT_ASSESSED verify stops run, appends ledger, not counted done', () async {
      final notAssessedBin = File(p.join(tmpDir.path, 'notassessed.dart'));
      await notAssessedBin.writeAsString('''
import 'dart:io';
void main(List<String> args) {
  if (args.contains('verify')) {
    print('mutation: gate=NOT_ASSESSED killed=0 survived=0 timed_out=0 mutation_was_run=false');
    exit(1);
  }
  print('run: feature=test result=complete');
  exit(0);
}
''');

      final runner = CorpusRunner(
        projectRoot: projectDir.path,
        progressStore: store,
        gapLedger: ledger,
        zfaBin: notAssessedBin.path,
      );

      final outcomes = await runner.run(
        manifestFeatures: ['001-na', '002-later'],
        readiness: {'001-na': true, '002-later': true},
      );

      // Only first feature attempted.
      expect(outcomes.length, 1);
      expect(outcomes.first.state, CorpusFeatureState.stopped);
      expect(outcomes.first.stoppedAt, 'verify');

      // 002-later was NOT started.
      final progress = await store.load();
      expect(progress!.features.containsKey('002-later'), false);

      // Ledger entry for NOT_ASSESSED.
      final entries = await ledger.load();
      expect(entries.length, 1);
      expect(entries.first.outcome, 'NOT_ASSESSED');

      // Not counted as done.
      expect(outcomes.first.state, isNot(CorpusFeatureState.done));
    });
  });
}
