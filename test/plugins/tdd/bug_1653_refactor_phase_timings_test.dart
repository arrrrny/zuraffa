@Tags(['slow'])
// Bug #1653 — the refactor cycle-log entry records no per-phase durations;
// "without heartbeats the 8m32s would be indistinguishable from a stuck
// step". The remediation adds per-phase durations (preflight / registry /
// re-proof) to the refactor receipt plus a per-pass wall duration on every
// recorded action, rendered as ADDITIVE lines outside the chain-hash
// payload (schema v1 preserved).
//
// RED first (spec 1653 T004): these tests pin the new contract BEFORE the
// implementation lands.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/refactor_action.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';
import 'package:zuraffa/src/plugins/tdd/services/refactor_passes.dart';

import 'helpers/tdd_fixture.dart';

/// A fake process executor that delays each pass by [delay] so the recorded
/// per-pass duration is provably non-null (and grows with the delay).
class _DelayingExecutor implements ProcessExecutor {
  _DelayingExecutor(this.delay);

  final Duration delay;

  @override
  Future<ProcessRunOutcome> run(RefactorPassInvocation inv) async {
    await Future<void>.delayed(delay);
    return ProcessRunOutcome(
      command: inv.command,
      exitCode: 0,
      output: 'ok',
      startedProcess: true,
    );
  }
}

/// Minimal scratch project for the registry (mirrors refactor_passes_test).
Directory _scratch() {
  final dir = Directory.systemTemp.createTempSync('bug_1653_passes_');
  Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
  File(p.join(dir.path, 'lib', 'main.dart'))
      .writeAsStringSync('void main() {}\n');
  return dir;
}

void main() {
  group('bug #1653 — per-pass duration (FR-008)', () {
    test('every executed pass records a non-null wall duration', () async {
      final project = _scratch();
      try {
        final passes = RefactorPasses(
          project.path,
          executor: _DelayingExecutor(const Duration(milliseconds: 15)),
          buildSkipGate: () async => null,
        );
        final result = await passes.run();
        expect(result.completed, isTrue);
        for (final action in result.actions) {
          expect(
            action.duration,
            isNotNull,
            reason:
                'issue #1653: without per-pass heartbeats a stuck pass is '
                'indistinguishable from a fast one in the receipt',
          );
          expect(
            action.duration!,
            greaterThanOrEqualTo(const Duration(milliseconds: 15)),
          );
        }
      } finally {
        project.deleteSync(recursive: true);
      }
    });

    test('a scheduling-skipped pass records NO duration (nothing ran)',
        () async {
      final project = _scratch();
      try {
        final passes = RefactorPasses(
          project.path,
          executor: _DelayingExecutor(Duration.zero),
          buildSkipGate: () async => 'nothing to build (test gate)',
        );
        final result = await passes.run();
        final build = result.actions.first;
        expect(build.skipped, isTrue);
        expect(build.duration, isNull);
      } finally {
        project.deleteSync(recursive: true);
      }
    });
  });

  group('bug #1653 — receipt rendering (FR-007)', () {
    test('the refactor entry renders the additive - phases: line', () {
      final entry = CycleLogEntry(
        behaviorId: 'feat-refactor',
        kind: CycleEntryKind.refactor,
        runnerCommand: 'dart test',
        exitCode: 0,
        capturedOutput: 'preflight: green\nre-proof: green\n',
        sourceCriterion: 'FR-007',
        testPath: 'test/',
        timestamp: '2026-09-16T00:00:00.000Z',
        refactorActions: [
          const RefactorAction(
            name: 'format',
            command: 'dart format lib/',
            exitCode: 0,
            filesChanged: [],
            output: 'ok',
            duration: Duration(milliseconds: 1500),
          ),
        ],
        phaseDurations: {
          'preflight': const Duration(seconds: 12, milliseconds: 340),
          'registry': const Duration(seconds: 2),
          're-proof': const Duration(minutes: 1, seconds: 5),
        },
      );
      final md = entry.toMarkdown();
      expect(
        md,
        contains('- phases: preflight=12.3s registry=2.0s re-proof=1m05s'),
        reason: 'the receipt must carry per-phase durations (issue #1653)',
      );
      expect(md, contains('  duration: 1.5s'));
    });

    test('an entry WITHOUT durations renders no - phases: line and hashes '
        'identically to the same entry with durations unset (schema v1: '
        'additive lines stay outside the chain payload)', () {
      CycleLogEntry entry({
        Map<String, Duration>? phases,
        Duration? actionDuration,
      }) =>
          CycleLogEntry(
            behaviorId: 'feat-refactor',
            kind: CycleEntryKind.refactor,
            runnerCommand: 'dart test',
            exitCode: 0,
            capturedOutput: 'preflight: green\nre-proof: green\n',
            sourceCriterion: 'FR-007',
            testPath: 'test/',
            timestamp: '2026-09-16T00:00:00.000Z',
            refactorActions: [
              RefactorAction(
                name: 'format',
                command: 'dart format lib/',
                exitCode: 0,
                filesChanged: const [],
                output: 'ok',
                duration: actionDuration,
              ),
            ],
            phaseDurations: phases,
          );

      final legacy = entry();
      final timed = entry(
        phases: {
          'preflight': const Duration(seconds: 1),
          'registry': const Duration(seconds: 2),
          're-proof': const Duration(seconds: 3),
        },
        actionDuration: const Duration(seconds: 2),
      );

      expect(legacy.toMarkdown(), isNot(contains('- phases:')));
      expect(legacy.toMarkdown(), isNot(contains('  duration:')));
      // Legacy entries still parse the same: the certified-facts block the
      // chain hash covers is byte-identical between the two shapes up to the
      // additive lines.
      final legacyMd = legacy.toMarkdown();
      final timedMd = timed.toMarkdown();
      expect(timedMd, contains('- phases:'));
      expect(timedMd, contains('  duration:'));
      // The chain payload covers behavior/kind/exit/command/criterion/test/
      // timestamp — identical for both entries.
      expect(
        CycleLog.chainHashFor(
          legacy,
          prevHash: CycleLog.genesisHash,
        ),
        CycleLog.chainHashFor(
          timed,
          prevHash: CycleLog.genesisHash,
        ),
        reason:
            'the duration lines are additive evidence OUTSIDE the chain-hash '
            'payload — the hash must not move when they are added',
      );
    });
  });

  group('bug #1653 — refactor green path carries the timings (FR-006)', () {
    test('a green refactor prints phase timings and writes them into the '
        'cycle-log receipt', () async {
      final fx = await TddFixture.create();
      final fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
      try {
        // Malformed lib: the format/fix passes CHANGE files, so the re-proof
        // is NOT inherited (#1624) — the phase actually runs and records a
        // duration. (A clean no-op refactor honestly records none: the
        // re-proof was inherited, no suite ran.)
        await fx.seedMalformedLib();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'refactor',
          '--project',
          fx.root.path,
          '--zfa-bin',
          fakeZfa,
        ]);

        expect(
          out,
          contains('phase timings: preflight='),
          reason:
              'the green path must print the per-phase durations '
              '(issue #1653 FR-006)',
        );
        expect(out, contains('registry='));
        expect(out, contains('re-proof='));
        // FR-009 contract line stays byte-unchanged in format.
        expect(
          out,
          contains(
            RegExp(
              r'refactor: feature=\S+ outcome=(clean|refactored) applied=\d+',
            ),
          ),
        );

        final cycleLog = File(fx.cycleLogPath).readAsStringSync();
        expect(
          cycleLog,
          contains('- phases: preflight='),
          reason: 'the RECEIPT (cycle-log entry) must carry the durations',
        );
        expect(cycleLog, contains('registry='));
        expect(cycleLog, contains('re-proof='));
      } finally {
        fx.dispose();
        exitCode = 0;
      }
    });
  });
}
