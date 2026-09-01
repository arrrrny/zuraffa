/// `CompositionPlanner` — the pure fallback planner for the acceptance
/// composition surface (spec 052-acceptance-make-composition; issue #642;
/// FR-007, FR-008).
///
/// When the primary `GenerationPlanner` refuses an acceptance behavior's
/// prose (its by-design, description-keyed refusal — planner purity is
/// preserved byte-for-byte, SC-006), the make command consults THIS
/// planner: given the behavior summary and the discovered composable green
/// unit subjects, it shapes the composition plan
///
///     zfa tdd compose <id> --feature <f>
///     zfa build
///
/// executed through the existing `PipelineRunner` — the same
/// `GenerationPlan` shape the primary planner returns, terminating in a
/// `build` step (the 047 FR-005 rule: build is the only step that produces
/// compile-validated output).
///
/// The planner is pure: it takes the summary and the anchor list and
/// returns a plan. It never reads or writes files, never invokes
/// subprocesses, and knows nothing about run phases or run state — the
/// phase-2 awareness of the fallback emerges from the discovery layer's
/// "already-green" precondition (units must be green for anchors to
/// exist), not from any planner state.
library;

import 'generation_planner.dart';
import 'composition_targets.dart';
import '../models/generation_plan.dart';

class CompositionPlanner {
  const CompositionPlanner();

  /// Plan the composition of [summary]'s subject against [anchors].
  ///
  /// The caller (the make command) MUST have confirmed [anchors] is
  /// non-empty (the discovery's `no-green-units` outcome must be reported
  /// as the honest unexpressible stop, not composed away — FR-009).
  GenerationPlan plan(
    BehaviorSummary summary,
    List<ComposableUnitSubject> anchors,
  ) {
    return GenerationPlan(
      behaviorId: summary.behaviorId,
      feature: summary.feature,
      sourceCriterion: summary.sourceCriterion,
      steps: [
        GenerationStepSpec(
          args: [
            'tdd',
            'compose',
            summary.behaviorId,
            '--feature',
            summary.feature,
          ],
          purpose:
              'compose subject of behavior ${summary.behaviorId} against '
              '${anchors.length} green unit subject(s)',
        ),
        GenerationStepSpec(
          args: ['build'],
          purpose: 'build composed code for behavior ${summary.behaviorId}',
        ),
      ],
    );
  }
}
