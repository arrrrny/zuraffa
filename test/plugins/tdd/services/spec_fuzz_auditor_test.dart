/// Unit tests for the spec-fuzz referee (spec 0967-spec-mutation-arena):
/// the P1/P2/P3 pin oracle, per-mutant capture/restore, gate decisions,
/// ledger integration, and deterministic reporting — with injectable
/// spawns (the MutationAuditor seam pattern).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/spec_mutation.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/source_restorer.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_fuzz_auditor.dart';

import '../../../helpers/arena_greeter_fixture.dart';

void main() {
  tearDown(() => exitCode = 0);

  group('weak fixture: every mutant survives and is flagged', () {
    test('gate fail_survived, ledger gaps appended, exit semantics', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));

      final specBefore = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();

      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
        ledgerStore: GapLedgerStore(
          fx.root.path,
          clock: () => DateTime.utc(2026, 1, 1),
        ),
      );
      final report = await auditor.run();

      expect(report.gate, SpecFuzzGateDecision.failSurvived);
      expect(report.survivedCount, greaterThan(0));
      expect(report.killedCount, 0);
      expect(report.certified, isFalse);
      expect(report.restorationVerified, isTrue);

      // Every survived row names its pins checked-and-silent.
      for (final outcome in report.outcomes) {
        if (outcome.verdict == SpecFuzzVerdict.survived) {
          expect(outcome.evidence, contains('no pin fired'));
        }
      }

      // Ledger: one deduplicated contract gap per survivor.
      final ledger = GapLedgerStore(
        fx.root.path,
        clock: () => DateTime.utc(2026, 1, 1),
      );
      final entries = await ledger.load();
      expect(entries.length, report.survivedCount);
      expect(entries.every((e) => e.severity == 'contract'), isTrue);
      expect(entries.every((e) => e.expectedResult == 'pass'), isTrue);

      // spec.md restored byte-exactly.
      final specAfter = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();
      expect(specAfter, specBefore);

      // Machine summary line (the CI contract).
      final line = report.summaryLine();
      expect(line, startsWith('spec-fuzz: feature=fixture-greeter'));
      expect(line, contains('survived=${report.survivedCount}'));
      expect(line, contains('certified=false'));
      expect(line, contains('fuzz_was_run=true'));

      // Report files written.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.md')).existsSync(),
        isTrue,
      );

      // Second run: no duplicate ledger rows (dedupe on unresolved
      // feature + mutation_id).
      final auditor2 = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
        ledgerStore: ledger,
      );
      await auditor2.run();
      expect((await ledger.load()).length, report.survivedCount);
    });

    test('re-running with --no-ledger never touches the ledger', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        ledgerEnabled: false,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      final report = await auditor.run();
      expect(report.ledgerEntryIds, isEmpty);
      expect(
        File(
          p.join(fx.root.path, '.zfa', 'corpus', 'gap-ledger.json'),
        ).existsSync(),
        isFalse,
      );
    });
  });

  group('strong fixture: every mutant is killed', () {
    test('gate pass, certified=true, pins recorded', () async {
      final fx = await ArenaGreeterFixture.greeter(strong: true);
      addTearDown(() => fx.root.delete(recursive: true));

      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      final report = await auditor.run();

      expect(report.gate, SpecFuzzGateDecision.pass);
      expect(report.survivedCount, 0);
      expect(report.notAssessedCount, 0);
      expect(report.killedCount, greaterThan(0));
      expect(report.certified, isTrue);
      expect(report.summaryLine(), contains('certified=true'));

      // The kill evidence names a fired pin for every killed mutant.
      for (final outcome in report.outcomes) {
        expect(outcome.verdict, SpecFuzzVerdict.killed);
        expect(outcome.pins, isNotEmpty);
        expect(
          outcome.evidence,
          anyOf(contains('P1'), contains('P2'), contains('P3')),
        );
      }

      // P2 must have actually fired for the FR-001 number swap: the
      // regenerated test asserted the swapped number and went red.
      final swap42 = report.outcomes.where(
        (o) => o.candidate.element == 'FR-001:literal:42',
      );
      expect(swap42, isNotEmpty);
      expect(swap42.single.pins, contains('P2:loop-red'));

      // Determinism: a fresh run over the same fixture is byte-identical.
      final json1 = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      final auditor2 = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      await auditor2.run();
      final json2 = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      expect(json2, json1);
    });
  });

  group('honest refusals', () {
    test('missing artifacts registry: not_assessed', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      File(p.join(fx.featureDir, 'tdd', 'artifacts.json')).deleteSync();
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
      );
      final report = await auditor.run();
      expect(report.gate, SpecFuzzGateDecision.notAssessed);
      expect(report.notAssessedReason, contains('no behavior artifacts'));
      expect(report.certified, isFalse);
    });

    test('red preflight: preflight_red gate (refuse to fuzz red)', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult(exitCode: 1, output: 'some test failed'),
      );
      final report = await auditor.run();
      expect(report.gate, SpecFuzzGateDecision.preflightRed);
      expect(report.mutationWasRun, isFalse);
    });

    test(
      'spawn load failure: not_assessed for that mutant, never a kill',
      () async {
        final fx = await ArenaGreeterFixture.greeter();
        addTearDown(() => fx.root.delete(recursive: true));
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: (_, args, _, _) async {
            final path = args.where((a) => a.endsWith('_test.dart')).first;
            return ProcessResult(
              42,
              253,
              'Failed to load "$path": compile error',
              '',
            );
          },
        );
        final report = await auditor.run();
        expect(report.gate, SpecFuzzGateDecision.notAssessed);
        expect(report.notAssessedCount, greaterThan(0));
        // Every mutant that SPAWNED graded not_assessed (infrastructure);
        // the drop mutant needs no spawn, so it alone may survive — never
        // an invented kill, never a pass.
        expect(
          report.notAssessedCount + report.survivedCount,
          report.outcomes.length,
        );
        expect(report.killedCount, 0);
      },
    );

    test(
      'no mutation candidates: not_assessed, never a vacuous pass',
      () async {
        final fx = await ArenaGreeterFixture.greeter();
        addTearDown(() => fx.root.delete(recursive: true));
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          operators: const {SpecMutationOperator.widen},
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: fakeSpawn,
        );
        final report = await auditor.run();
        expect(report.gate, SpecFuzzGateDecision.notAssessed);
        expect(report.notAssessedReason, contains('no mutation candidates'));
        expect(report.certified, isFalse);
      },
    );
  });

  group('budget and seed', () {
    test('budget caps the mutants and is recorded', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        budget: 2,
        seed: 0,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      final report = await auditor.run();
      expect(report.outcomes, hasLength(2));
      expect(report.budget, 2);
      expect(report.candidateCount, greaterThan(2));
      expect(report.summaryLine(), contains('budget=2'));
    });

    test('the same seed selects the same mutants', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      Future<SpecFuzzReport> run(int seed) async {
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          budget: 2,
          seed: seed,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: fakeSpawn,
        );
        return auditor.run();
      }

      final a = await run(11);
      final b = await run(11);
      expect(
        a.outcomes.map((o) => o.candidate.mutationId).toList(),
        b.outcomes.map((o) => o.candidate.mutationId).toList(),
      );
    });
  });

  group('report shape', () {
    test('machine rows carry the issue contract fields', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      await auditor.run();
      final decoded =
          jsonDecode(
                File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(decoded['schema'], 'spec-fuzz.v1');
      final mutations = decoded['mutations'] as List;
      expect(mutations, isNotEmpty);
      for (final row in mutations.cast<Map<String, dynamic>>()) {
        expect(row.containsKey('mutation_id'), isTrue);
        expect(row.containsKey('spec_line'), isTrue);
        expect(row.containsKey('operator'), isTrue);
        expect(row.containsKey('verdict'), isTrue);
        expect(row.containsKey('evidence'), isTrue);
      }
      expect(decoded['seed'], 0);
      expect(decoded.containsKey('certified'), isTrue);
      final restoration = decoded['restoration'] as Map<String, dynamic>;
      expect(restoration.containsKey('verified'), isTrue);
    });

    test('spec hash binds the report to the audited spec bytes', () async {
      final fx = await ArenaGreeterFixture.greeter();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: fakeSpawn,
      );
      final report = await auditor.run();
      final specHash = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();
      expect(report.specHash, specHash);
    });
  });

  group('restoration safety (SourceRestorer)', () {
    test('uncaptured restorer reports restorationFailed', () async {
      final tmpDir = Directory.systemTemp.createTempSync('restoration_test');
      final testFile = File(p.join(tmpDir.path, 'test.txt'))
        ..writeAsStringSync('original');
      addTearDown(() => tmpDir.delete(recursive: true));

      final restorer = SourceRestorer(paths: [testFile.path]);
      // Deliberately skip capture().
      final result = await restorer.restoreAndVerify();

      expect(result.restorationVerified, isFalse);
      expect(result.restorationFailed, isTrue);
    });

    test('captured restorer verifies successfully on identical file', () async {
      final tmpDir = Directory.systemTemp.createTempSync('restoration_test');
      final testFile = File(p.join(tmpDir.path, 'test.txt'))
        ..writeAsStringSync('original content');
      addTearDown(() => tmpDir.delete(recursive: true));

      final restorer = SourceRestorer(paths: [testFile.path]);
      await restorer.capture();
      final result = await restorer.restoreAndVerify();

      expect(result.restorationVerified, isTrue);
      expect(result.restorationFailed, isFalse);
    });
  });
}
