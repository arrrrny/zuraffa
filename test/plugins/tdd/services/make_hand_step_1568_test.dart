// SPEC 1568 — the make hand-step classification core (fast tier).
//
// The planner announces hand-step behaviors upfront (SPEC 1489 SC-4's
// `Seam cost` forecast: entity-return contract subjects), but `make`
// treated the SAME condition as `generation-error` and stopped the run.
// The classification core keys on the declared contract TYPE SHAPE —
// registry-independent (phase-0 may create the entity between the
// forecast and the make; the verdict must stay stable across that
// boundary) — and mirrors the forecast's announced class exactly.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/hand_step_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/step_runner.dart';

void main() {
  group(
    'A-1568-m1: MakeOutcome.handStep is a first-class non-green outcome',
    () {
      test('the outcome exists with the machine label `hand-step`', () {
        expect(MakeOutcome.handStep.label, 'hand-step');
      });

      test('the outcome is NOT in the make green family — the run loop must '
          'never read it as a certified generation', () async {
        // Review fix: exercise StepRunner's REAL success classifier (the
        // one the run loop consults) through its documented summary-line
        // contract, instead of re-declaring the family literal — a
        // regression that added `hand-step` to the production list turns
        // the first expectation red, which the local list never could.
        Future<StepResult> runMake(String outcome) =>
            StepRunner(
              zfaBin: '/fake/zfa',
              spawner: (command, workingDirectory) async => ProcessResult(
                0,
                0,
                'make: behavior=U1 outcome=$outcome feature=demo',
                '',
              ),
            ).run(
              step: 'make',
              behaviorId: 'U1',
              feature: 'demo',
              projectRoot: '.',
            );

        // A zero-exit make carrying the hand-step token is NOT a success.
        final handStep = await runMake('hand-step');
        expect(handStep.outcome, 'hand-step');
        expect(handStep.success, isFalse);

        // The same shape with a certified token IS a success — the
        // classifier is live, so the assertion above is not vacuous.
        final green = await runMake('green');
        expect(green.outcome, 'green');
        expect(green.success, isTrue);
      });
    },
  );

  group('A-1568-m2: the classifier keys on the declared return TYPE SHAPE', () {
    test('entity-shaped declared returns classify hand-step (the SPEC 1489 '
        'seam class — "will hand-step because return is an entity")', () {
      // The issue's exact subject: `ScanSession scan() => throw
      // UnimplementedError(...)`.
      expect(HandStepClassifier.isEntityShapedReturn('ScanSession'), isTrue);
      expect(HandStepClassifier.isEntityShapedReturn('Task'), isTrue);
      // Nullable and container shapes ride the entity inside.
      expect(HandStepClassifier.isEntityShapedReturn('Task?'), isTrue);
      expect(HandStepClassifier.isEntityShapedReturn('List<Task>'), isTrue);
      expect(
        HandStepClassifier.isEntityShapedReturn('Map<String, Task>'),
        isTrue,
      );
      expect(
        HandStepClassifier.isEntityShapedReturn('Iterable<ScanSession>'),
        isTrue,
      );
    });

    test('renderable scalars and scalar containers NEVER classify '
        'hand-step — func serves them mechanically (the #1310 lineage)', () {
      for (final scalar in [
        'bool',
        'String',
        'int',
        'double',
        'num',
        'dynamic',
        'Object',
        'Never',
        'void',
        'bool?',
        'String?',
        'List<int>',
        'Map<String, int>',
      ]) {
        expect(
          HandStepClassifier.isEntityShapedReturn(scalar),
          isFalse,
          reason: '$scalar is a renderable scalar shape',
        );
      }
    });

    test('a core value type the func lane cannot rewrite (DateTime) is '
        'entity-shaped here EXACTLY when the planner forecast counts it '
        '(no DateTime entity file exists in a fresh project)', () {
      // The forecast counts `!shape.scalarOutcome` after registry
      // resolution; `DateTime` is not a UnitContractShape renderable
      // scalar, so a fresh project (no such entity file) counts it.
      // The classifier mirrors the type-shape half of that predicate —
      // the registry-independent half — so the two agree on the class.
      expect(HandStepClassifier.isEntityShapedReturn('DateTime'), isTrue);
    });

    test('whitespace-padded declared returns classify on the trimmed '
        'shape (the parser-verbatim form)', () {
      expect(
        HandStepClassifier.isEntityShapedReturn('  ScanSession  '),
        isTrue,
      );
      expect(HandStepClassifier.isEntityShapedReturn('  int  '), isFalse);
    });
  });
}
