// Bug #805 — generator differential testing (vision slice v0).
//
// The result vector is the differential's unit of comparison: one
// EntryVector per (corpus entry, generator ref) pair, holding one
// StepVector per driven step (exit code, behavioral outcome class,
// machine token, dart-test pass/fail counts) plus the artifact
// inventory (paths, deliberately not bytes). These tests pin the
// equality semantics the compare step relies on and the finding
// classes the report renders.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/differential_vector.dart';

void main() {
  group('StepVector', () {
    test('outcome classes are exactly complete/failed/hang (issue #805)', () {
      expect(DifferentialStepOutcome.values.map((o) => o.name).toSet(), {
        'complete',
        'failed',
        'hang',
      });
    });

    test('equality covers every recorded field', () {
      const a = StepVector(
        label: 'gen U2',
        exitCode: 0,
        outcome: DifferentialStepOutcome.complete,
        token: 'created',
        passCount: 3,
        failCount: 0,
      );
      expect(
        a,
        equals(
          const StepVector(
            label: 'gen U2',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
            token: 'created',
            passCount: 3,
            failCount: 0,
          ),
        ),
      );
      // A different outcome class is the behavioral difference the gate
      // exists to catch (#744: hang vs complete).
      expect(a, isNot(equals(a.copyWithOutcome(DifferentialStepOutcome.hang))));
      expect(
        a,
        isNot(
          equals(
            const StepVector(
              label: 'gen U2',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
          ),
        ),
        reason:
            'a missing token (unparseable machine line) is a different '
            'observation, never silently equal',
      );
    });

    test('a hang records exitCode -1 and the hang outcome', () {
      const a = StepVector(
        label: 'gen U2',
        exitCode: -1,
        outcome: DifferentialStepOutcome.hang,
      );
      expect(a.outcome, DifferentialStepOutcome.hang);
      expect(a.exitCode, -1);
    });
  });

  group('EntryVector', () {
    EntryVector build({
      String entry = 'u2-flow',
      String ref = 'HEAD',
      List<StepVector>? steps,
      List<String>? artifacts,
    }) => EntryVector(
      entry: entry,
      ref: ref,
      steps:
          steps ??
          const [
            StepVector(
              label: 'gen U1',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
            StepVector(
              label: 'gen U2',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
          ],
      artifacts:
          artifacts ?? const ['lib/tdd/u1.dart', 'test/tdd/u1_test.dart'],
    );

    test('deep equality: steps and artifacts must all agree', () {
      expect(build(), equals(build()));
      expect(
        build(),
        isNot(equals(build(ref: 'origin/master'))),
        reason: 'the ref label is part of the vector identity',
      );
      expect(
        build(artifacts: ['lib/tdd/u1.dart']),
        isNot(equals(build())),
        reason:
            'a missing artifact is a behavioral difference (#805: '
            'artifact inventory, not bytes)',
      );
      expect(
        build(
          steps: const [
            StepVector(
              label: 'gen U1',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
          ],
        ),
        isNot(equals(build())),
        reason: 'a dropped step changes the executed shape of the entry',
      );
    });

    test('artifacts are order-insensitive (normalized sorted at build)', () {
      final a = EntryVector(
        entry: 'u2-flow',
        ref: 'HEAD',
        steps: const [],
        artifacts: const ['test/tdd/b.dart', 'test/tdd/a.dart'],
      );
      expect(a.artifacts, ['test/tdd/a.dart', 'test/tdd/b.dart']);
    });

    test('outcomeSummary joins per-step outcome names in order', () {
      expect(build().outcomeSummary, 'complete, complete');
      expect(
        build(
          steps: const [
            StepVector(
              label: 'gen U2',
              exitCode: -1,
              outcome: DifferentialStepOutcome.hang,
            ),
          ],
        ).outcomeSummary,
        'hang',
      );
    });
  });

  group('compareEntryVectors', () {
    test('identical vectors produce no findings', () {
      const steps = [
        StepVector(
          label: 'gen U1',
          exitCode: 0,
          outcome: DifferentialStepOutcome.complete,
        ),
      ];
      final from = EntryVector(
        entry: 'u2-flow',
        ref: 'a',
        steps: steps,
        artifacts: ['test/tdd/u1_test.dart'],
      );
      final to = EntryVector(
        entry: 'u2-flow',
        ref: 'b',
        steps: steps,
        artifacts: ['test/tdd/u1_test.dart'],
      );
      expect(compareEntryVectors(from: from, to: to), isEmpty);
    });

    test('a step outcome divergence is a step finding naming both sides', () {
      final from = EntryVector(
        entry: 'u2-flow',
        ref: 'broken',
        steps: [
          StepVector(
            label: 'gen U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
          StepVector(
            label: 'gen U2',
            exitCode: -1,
            outcome: DifferentialStepOutcome.hang,
          ),
        ],
      );
      final to = EntryVector(
        entry: 'u2-flow',
        ref: 'HEAD',
        steps: [
          StepVector(
            label: 'gen U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
          StepVector(
            label: 'gen U2',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
        ],
      );
      final findings = compareEntryVectors(from: from, to: to);
      expect(findings, hasLength(1));
      expect(findings.single.kind, 'step');
      expect(findings.single.detail, contains('gen U2'));
      expect(findings.single.detail, contains('hang'));
      expect(findings.single.detail, contains('complete'));
    });

    test('a machine-token divergence is a step finding even at exit 0', () {
      final from = EntryVector(
        entry: 'e',
        ref: 'a',
        steps: [
          StepVector(
            label: 'make U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
            token: 'pass',
          ),
        ],
      );
      final to = EntryVector(
        entry: 'e',
        ref: 'b',
        steps: [
          StepVector(
            label: 'make U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
            token: 'red',
          ),
        ],
      );
      final findings = compareEntryVectors(from: from, to: to);
      expect(findings.single.kind, 'step');
      expect(findings.single.detail, contains('pass'));
      expect(findings.single.detail, contains('red'));
    });

    test('pass/fail count divergences are count findings', () {
      final from = EntryVector(
        entry: 'e',
        ref: 'a',
        steps: [
          StepVector(
            label: 'dart test',
            exitCode: 65,
            outcome: DifferentialStepOutcome.failed,
            passCount: 0,
            failCount: 2,
          ),
        ],
      );
      final to = EntryVector(
        entry: 'e',
        ref: 'b',
        steps: [
          StepVector(
            label: 'dart test',
            exitCode: 65,
            outcome: DifferentialStepOutcome.failed,
            passCount: 2,
            failCount: 0,
          ),
        ],
      );
      final findings = compareEntryVectors(from: from, to: to);
      expect(findings.map((f) => f.kind), contains('counts'));
      final counts = findings.firstWhere((f) => f.kind == 'counts');
      expect(counts.detail, contains('+0 -2'));
      expect(counts.detail, contains('+2 -0'));
    });

    test('artifact inventory divergence: added and removed findings', () {
      final from = EntryVector(
        entry: 'e',
        ref: 'a',
        steps: [],
        artifacts: ['lib/tdd/old.dart', 'lib/tdd/shared.dart'],
      );
      final to = EntryVector(
        entry: 'e',
        ref: 'b',
        steps: [],
        artifacts: ['lib/tdd/new.dart', 'lib/tdd/shared.dart'],
      );
      final findings = compareEntryVectors(from: from, to: to);
      final kinds = findings.map((f) => f.kind);
      expect(kinds, contains('artifact-added'));
      expect(kinds, contains('artifact-removed'));
      expect(
        findings.firstWhere((f) => f.kind == 'artifact-added').detail,
        contains('lib/tdd/new.dart'),
      );
      expect(
        findings.firstWhere((f) => f.kind == 'artifact-removed').detail,
        contains('lib/tdd/old.dart'),
      );
    });

    test('a step-count mismatch is a step finding, never a range error', () {
      final from = EntryVector(
        entry: 'e',
        ref: 'a',
        steps: [
          StepVector(
            label: 'gen U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
        ],
      );
      final to = EntryVector(
        entry: 'e',
        ref: 'b',
        steps: [
          StepVector(
            label: 'gen U1',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
          StepVector(
            label: 'gen U2',
            exitCode: 0,
            outcome: DifferentialStepOutcome.complete,
          ),
        ],
      );
      final findings = compareEntryVectors(from: from, to: to);
      expect(findings, hasLength(1));
      expect(findings.single.kind, 'step');
      expect(findings.single.detail, contains('gen U2'));
    });

    test(
      'the reverse direction (from has more steps than to) is also a '
      'step finding',
      () {
        final from = EntryVector(
          entry: 'e',
          ref: 'a',
          steps: [
            StepVector(
              label: 'gen U1',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
            StepVector(
              label: 'gen U2',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
          ],
        );
        final to = EntryVector(
          entry: 'e',
          ref: 'b',
          steps: [
            StepVector(
              label: 'gen U1',
              exitCode: 0,
              outcome: DifferentialStepOutcome.complete,
            ),
          ],
        );
        final findings = compareEntryVectors(from: from, to: to);
        expect(findings, hasLength(1));
        expect(findings.single.kind, 'step');
        expect(findings.single.detail, contains('gen U2'));
      },
    );
  });
}
