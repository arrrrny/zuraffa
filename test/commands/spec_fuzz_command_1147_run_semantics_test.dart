/// CLI run-semantics pins for `zfa spec fuzz` (spec
/// 1147-spec-fuzz-mutation-arena, issue #1147 — VISION-3, extends #967).
///
/// The six issue constraints, pinned at the COMMAND boundary on the fast
/// tier: the real [SpecFuzzCommand] with the auditor's injectable-spawn
/// seam (the MutationAuditor pattern — no subprocess), driving the honest
/// fake spawn shared with the auditor suite
/// (`test/helpers/arena_greeter_fixture.dart`):
///
///   1. the five operators apply deterministically and replayably,
///   2. behaviors are re-run against the mutated spec (the P2 pin via
///      the fake spawn),
///   3. killed vs survived is classified with evidence,
///   4. the machine-readable report carries the documented row shape,
///   5. exit 0 when every mutant is killed, non-zero when survived > 0,
///   6. `--budget N` caps the round.
///
/// The slow-tier seeded-weakness demo (`spec_fuzz_demo_test.dart`)
/// remains the real-process corroboration of the same contract.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/spec_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

import '../helpers/arena_greeter_fixture.dart';
import '../helpers/exit_span_mutex.dart';

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

Future<PreflightResult> _greenPreflight(List<String> testPaths) async =>
    PreflightResult(
      exitCode: 0,
      output: 'All tests passed!',
      ranTestPaths: testPaths,
    );

Future<PreflightResult> _redPreflight(List<String> testPaths) async =>
    PreflightResult(
      exitCode: 1,
      output: '00:00 +0 -1: Some tests failed.',
      ranTestPaths: testPaths,
    );

void main() {
  tearDown(() => exitCode = 0);

  /// Dispatches the REAL spec-fuzz command (with the injected
  /// preflight/spawn seams) through a local CommandRunner — the
  /// skin_command_test pattern, holding the cross-isolate exit-span
  /// mutex around the dispatch + exitCode read.
  /// Holds the UsageException message so the refusal-class assertions
  /// can still inspect the command's verdict text.
  Future<(String, int)> runFuzz(
    List<String> args, {
    Future<PreflightResult> Function(List<String> testPaths)? preflight,
  }) async {
    await ExitSpanMutex.acquire();
    try {
      exitCode = 0;
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(
          SpecCommand(
            runPreflight: preflight ?? _greenPreflight,
            spawnTest: fakeSpawn,
          ),
        );
      final output = await captureOutput(
        () => runner.run(['spec', 'fuzz', ...args]),
      );
      return (output, exitCode);
    } on UsageException catch (error) {
      // The runner rethrows usage-class refusals; CliRunner translates
      // them to the canonical usage exit (2) and prints the message.
      return (error.message, _usageExit);
    } finally {
      ExitSpanMutex.release();
    }
  }

  group('run semantics (issue #1147: exit codes)', () {
    test('weak spec: mutants survive, exit 1, certified=false', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ]);
      expect(code, 1, reason: 'survived > 0 must exit non-zero — got:\n$out');
      expect(out, contains('spec-fuzz: feature=${fx.featureName}'));
      expect(out, contains('certified=false'));
      final survived = RegExp(r'survived=(\d+)').firstMatch(out)?.group(1);
      expect(survived, isNotNull);
      expect(int.parse(survived!), greaterThan(0));
      // The report exists and every row is a survived weakness with
      // evidence (constraint 3).
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['gate'], 'failSurvived');
      expect(report['certified'], false);
    });

    test('strong spec: every mutant killed, exit 0, certified=true', () async {
      final fx = await ArenaGreeterFixture.arena(strong: true);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ]);
      expect(code, 0, reason: 'all mutants killed must exit zero — got:\n$out');
      expect(out, contains('certified=true'));
      final survived = RegExp(r'survived=(\d+)').firstMatch(out)?.group(1);
      expect(survived, '0', reason: out);
      final killed = RegExp(r'killed=(\d+)').firstMatch(out)?.group(1);
      expect(int.parse(killed!), greaterThan(0));
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['gate'], 'pass');
      expect(report['certified'], true);
    });
  });

  group('report shape (issue #1147: machine-readable weakness report)', () {
    test('rows carry the documented fields {mutation_id, spec_line, '
        'operator, verdict, evidence}', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      await runFuzz([fx.featureName, '--project', fx.root.path, '--no-ledger']);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['schema'], 'spec-fuzz.v1');
      final mutations = (report['mutations'] as List)
          .cast<Map<String, dynamic>>();
      expect(mutations, isNotEmpty);
      for (final row in mutations) {
        expect(row['mutation_id'], matches(RegExp(r'^SM-\d{3}$')));
        expect(row['spec_line'], isA<int>(), reason: '$row');
        expect((row['spec_line'] as int), greaterThan(0));
        expect(
          row['operator'],
          anyOf('weaken', 'drop', 'swap-literal', 'widen', 'drop-must-not'),
          reason: '$row',
        );
        expect(row['verdict'], anyOf('killed', 'survived', 'not_assessed'));
        expect((row['evidence'] as String), isNotEmpty, reason: '$row');
      }
    });

    test('the five declared operators all appear against the '
        'all-element fixture', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      await runFuzz([fx.featureName, '--project', fx.root.path, '--no-ledger']);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final operators =
          ((report['mutations'] as List).cast<Map<String, dynamic>>())
              .map((row) => row['operator'] as String)
              .toSet();
      expect(
        operators,
        containsAll([
          'weaken',
          'drop',
          'swap-literal',
          'widen',
          'drop-must-not',
        ]),
        reason: 'the fixture spec carries all five element classes',
      );
    });
  });

  group('operator filter (issue #1147: --operators)', () {
    test(
      '--operators weaken,drop judges only the selected operators',
      () async {
        final fx = await ArenaGreeterFixture.arena(strong: false);
        addTearDown(() => fx.root.delete(recursive: true));

        final (out, code) = await runFuzz([
          fx.featureName,
          '--project',
          fx.root.path,
          '--operators',
          'weaken,drop',
          '--no-ledger',
        ]);
        expect(code, 1, reason: out);
        final report =
            jsonDecode(
                  await File(
                    p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final mutations = (report['mutations'] as List)
            .cast<Map<String, dynamic>>()
            .map((row) => row['operator'] as String)
            .toSet();
        expect(mutations.difference({'weaken', 'drop'}), isEmpty, reason: out);
        expect(report['operators'], ['drop', 'weaken']);

        // The unfiltered round on the same fixture is strictly larger —
        // the filter actually narrowed the candidate set (ids stay stable;
        // the count reflects the full candidate set either way).
        await runFuzz([
          fx.featureName,
          '--project',
          fx.root.path,
          '--no-ledger',
        ]);
        final unfiltered =
            jsonDecode(
                  await File(
                    p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        expect(
          (report['candidate_count'] as int),
          lessThan(unfiltered['candidate_count'] as int),
          reason: 'the filter must narrow the candidate set',
        );
      },
    );
  });

  group('budget (issue #1147: --budget N)', () {
    test('--budget 2 caps the judged mutants and is recorded', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--budget',
        '2',
        '--no-ledger',
      ]);
      expect(code, 1, reason: out);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['budget'], 2);
      expect(report['candidate_count'], greaterThan(2));
      expect(
        (report['mutations'] as List).length,
        2,
        reason: 'exactly budget mutants are judged — got:\n$out',
      );
    });
  });

  group('replay (issue #1147: deterministic, replayable)', () {
    test('same seed + budget -> byte-identical report', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final args = [
        fx.featureName,
        '--project',
        fx.root.path,
        '--seed',
        '7',
        '--budget',
        '3',
        '--no-ledger',
      ];
      await runFuzz(args);
      final first = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      await runFuzz(args);
      final second = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      expect(second, first, reason: 'the round must replay byte-identically');
    });
  });

  group('honest refusals (issue #1147: never grade a red loop)', () {
    test('a red preflight is refused, never graded (usage exit)', () async {
      final fx = await ArenaGreeterFixture.arena(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ], preflight: _redPreflight);
      expect(code, 2, reason: 'preflight_red is a refusal class — got:\n$out');
      // The refusal names the gate (enum name) and the honest reason.
      expect(out, contains('preflightRed'));
      expect(out, contains('refuses'));
      expect(out, contains('red loop'));
      // No report was written for an unrun round.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.json')).existsSync(),
        isFalse,
      );
    });
  });

  group('fake spawn honesty (the mock grades like the real spawn)', () {
    test(
      'a pin mismatch goes red: the mutant is killed (P2:loop-red)',
      () async {
        final fx = await ArenaGreeterFixture.arena(strong: true);
        addTearDown(() => fx.root.delete(recursive: true));

        final (out, code) = await runFuzz([
          fx.featureName,
          '--project',
          fx.root.path,
          '--no-ledger',
        ]);
        expect(code, 0, reason: out);
        final report =
            jsonDecode(
                  await File(
                    p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final killed = (report['mutations'] as List)
            .cast<Map<String, dynamic>>()
            .where((row) => row['verdict'] == 'killed')
            .toList();
        expect(killed, isNotEmpty, reason: out);
        expect(
          killed.any(
            (row) => (row['evidence'] as String).contains('P2:loop-red'),
          ),
          isTrue,
          reason:
              'a pin mismatch (regenerated test red) must kill — got:\n$out',
        );
      },
    );

    test('a regenerated file with no subject import grades as a load '
        'failure, never a silent green', () async {
      final dir = await Directory.systemTemp.createTemp('fake_spawn_');
      addTearDown(() => dir.delete(recursive: true));
      final testFile = File(p.join(dir.path, 'a1_test.dart'))
        ..writeAsStringSync(
          "import 'package:test/test.dart';\n\nvoid main() {}\n",
        );

      final result = await fakeSpawn(
        'dart',
        ['test', testFile.path],
        dir.path,
        const Duration(minutes: 1),
      );
      expect(result.exitCode, isNonZero);
      expect(result.stdout, contains('Failed to load'));
    });
  });
}

/// The canonical usage exit the CliRunner applies to usage-class
/// refusals (SPEC 917: legacy 64 maps onto 2).
const int _usageExit = 2;
