// Spec 1529 — the make-step timeout receipt (US1).
//
// A make step killed at the run driver's deadline must leave an
// INSPECTABLE record: `specs/<feature>/tdd/make.<behaviorId>.timeout.json`
// carrying the child argv, the ACTUAL elapsed wall time, the inferred
// phase (compiling | running | unknown) with its evidence, and the
// captured output tail — so resume is an informed decision instead of a
// blind re-roll (the diagnose-blind kill from the issue's dogfood run).
//
// Fast tier: no real processes — the receipt model, the writer, and the
// scaled-budget / phase-inference helpers are pure functions over
// injected inputs.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_timeout_receipt.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

void main() {
  group('scaledStepBudget — the #1529 budget derivation (US2 / U1, U2)', () {
    test('4x a 9-minute measured baseline = 36 minutes', () {
      final budget = scaledStepBudget(
        measuredBaseline: const Duration(minutes: 9),
      );
      expect(budget, const Duration(minutes: 36));
    });

    test('a 4-minute baseline floors at 25 minutes', () {
      final budget = scaledStepBudget(
        measuredBaseline: const Duration(minutes: 4),
      );
      expect(budget, TddTimeouts.minStepBudget);
      expect(budget, const Duration(minutes: 25));
    });

    test('no measurement at all yields the 25-minute floor', () {
      expect(scaledStepBudget(), TddTimeouts.minStepBudget);
    });

    test('an explicit budget always wins over the derivation', () {
      final explicit = const Duration(minutes: 7);
      expect(
        scaledStepBudget(
          measuredBaseline: const Duration(minutes: 90),
          explicit: explicit,
        ),
        explicit,
        reason: 'the operator override is honored even when it looks unsafe',
      );
      expect(
        scaledStepBudget(explicit: explicit),
        explicit,
        reason: 'the override wins even with no measurement',
      );
    });

    test('the 4x multiple is the documented default', () {
      expect(
        scaledStepBudget(measuredBaseline: const Duration(minutes: 10)),
        const Duration(minutes: 40),
      );
    });
  });

  group('inferTimeoutPhase — evidence-carrying phase inference (U3)', () {
    test('a test-runner descendant grades running', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: [
          'dart bin/zfa.dart tdd make U8',
          '/usr/bin/flutter_tester --enable-software-rendering',
        ],
        output: 'zfa tdd make: behavior U8\n',
      );
      expect(verdict.phase, 'running');
      expect(verdict.evidence, contains('flutter_tester'));
    });

    test('a dart-test descendant grades running', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: [
          'dart run build_runner test -- -p chrome',
          'dart test test/some_test.dart',
        ],
        output: '',
      );
      expect(verdict.phase, 'running');
    });

    test('a compile/kernel descendant grades compiling', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: [
          'dart bin/zfa.dart tdd make U8',
          'dart jit-trainmain snapshot.dart',
        ],
        output: '',
      );
      // jit-trainmain is NOT a compile marker — the guard below proves
      // the inference is marker-driven, not keyword-greedy.
      final compiling = inferTimeoutPhase(
        descendantArgvs: [
          'dart bin/zfa.dart tdd make U8',
          '/usr/bin/frontend_server --target=flutter',
        ],
        output: '',
      );
      expect(verdict.phase, 'unknown');
      expect(compiling.phase, 'compiling');
    });

    test('build_runner and dart compile grade compiling', () {
      expect(
        inferTimeoutPhase(
          descendantArgvs: ['dart run build_runner build'],
          output: '',
        ).phase,
        'compiling',
      );
      expect(
        inferTimeoutPhase(
          descendantArgvs: ['dart compile kernel main.dart'],
          output: '',
        ).phase,
        'compiling',
      );
    });

    test('output markers grade running when no tree is observable', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: const [],
        output: '00:03 +1: loading test/some_test.dart\n',
      );
      expect(verdict.phase, 'running');
      expect(verdict.evidence, isNotEmpty);
    });

    test('no observable signal grades unknown, honestly', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: const [],
        output: 'zfa tdd make: behavior U8\n',
      );
      expect(verdict.phase, 'unknown');
      expect(verdict.evidence, contains('no'));
    });

    test('process-tree evidence outranks the captured-output markers', () {
      final verdict = inferTimeoutPhase(
        descendantArgvs: ['/usr/bin/frontend_server --target=flutter'],
        output: '00:03 +1: some test name\n',
      );
      expect(verdict.phase, 'compiling');
    });
  });

  group('StepTimeoutReceipt — the durable kill record (U5, U6)', () {
    test('round-trips every v1 field through JSON', () {
      final receipt = StepTimeoutReceipt(
        behaviorId: 'U8',
        step: 'make',
        argv: const ['dart', 'bin/zfa.dart', 'tdd', 'make', 'U8'],
        workingDirectory: '/workspace/001-todo-app',
        elapsed: const Duration(minutes: 25, seconds: 3),
        deadline: const Duration(minutes: 25),
        phase: inferTimeoutPhase(
          descendantArgvs: const ['/usr/bin/flutter_tester'],
          output: '',
        ),
        outputTail: 'zfa tdd make: behavior U8\n   feature: 001-todo-app\n',
        capturedAt: '2026-09-13T12:00:00.000Z',
      );
      final json = receipt.toJson();
      expect(json['schema'], 'tdd-make-timeout-receipt.v1');
      expect(json['behavior'], 'U8');
      expect(json['step'], 'make');
      expect(json['argv'], isA<List<dynamic>>());
      expect(json['elapsed_ms'], 25 * 60 * 1000 + 3000);
      expect(json['deadline_ms'], 25 * 60 * 1000);
      expect(json['phase'], 'running');
      expect(json['phase_evidence'], isA<String>());
      expect(json['output_tail'], contains('behavior U8'));
      expect(json['captured_at'], '2026-09-13T12:00:00.000Z');
      // Decodable, not just shape-checked.
      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(decoded['behavior'], 'U8');
    });

    test('fileNameFor matches the issue glob make.<id>.*.json', () {
      expect(StepTimeoutReceipt.fileNameFor('U8'), 'make.U8.timeout.json');
      expect(
        RegExp(
          r'^make\.u8\..+\.json$',
          caseSensitive: false,
        ).hasMatch(StepTimeoutReceipt.fileNameFor('U8')),
        isTrue,
        reason: 'the operator globs make.u8.*.json (issue #1529)',
      );
    });

    test(
      'write() lands the file in the feature tdd dir and returns it',
      () async {
        final featureDir = await Directory.systemTemp.createTemp('zfa1529_');
        addTearDown(() => featureDir.deleteSync(recursive: true));
        final receipt = StepTimeoutReceipt(
          behaviorId: 'U8',
          step: 'make',
          argv: const ['dart', 'bin/zfa.dart', 'tdd', 'make', 'U8'],
          elapsed: const Duration(minutes: 25),
          deadline: const Duration(minutes: 25),
          phase: const PhaseVerdict(phase: 'unknown', evidence: 'no signal'),
          outputTail: 'header only',
          capturedAt: '2026-09-13T12:00:00.000Z',
        );
        final path = await writeStepTimeoutReceipt(
          featureDir: featureDir.path,
          receipt: receipt,
        );
        expect(
          p.relative(path, from: featureDir.path),
          p.join('tdd', 'make.U8.timeout.json'),
        );
        final decoded =
            jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
        expect(decoded['schema'], 'tdd-make-timeout-receipt.v1');
        expect(decoded['behavior'], 'U8');
        expect(decoded['phase'], 'unknown');
      },
    );

    test(
      'write() is best-effort: an unwritable dir reports, never throws',
      () async {
        final featureDir = await Directory.systemTemp.createTemp('zfa1529_');
        addTearDown(() => featureDir.deleteSync(recursive: true));
        // A FILE where the tdd/ DIRECTORY must be — the write cannot land.
        File(p.join(featureDir.path, 'tdd')).writeAsStringSync('not a dir');
        final receipt = StepTimeoutReceipt(
          behaviorId: 'U8',
          step: 'make',
          argv: const ['dart'],
          elapsed: const Duration(minutes: 1),
          deadline: const Duration(minutes: 1),
          phase: const PhaseVerdict(phase: 'unknown', evidence: 'no signal'),
          outputTail: '',
          capturedAt: '2026-09-13T12:00:00.000Z',
        );
        final outcome = await writeStepTimeoutReceiptReported(
          featureDir: featureDir.path,
          receipt: receipt,
        );
        expect(outcome.written, isFalse);
        expect(outcome.path, isNull);
        expect(outcome.error, isNotNull);
      },
    );
  });
}
