/// `GenerationPlanner` — maps a behavior row to a minimal ordered
/// [GenerationPlan] (spec 047-tdd-make T005; FR-005; data-model.md).
///
/// The planner is the command's behavior→pipeline translation layer.
/// It is the SOLE place where a behavior's required generation steps
/// are derived; every other component consumes the plan it produces.
///
/// Mapping rules (minimal generation — FR-005):
///   - **Entity-bearing behavior** (description starts with "entity"
///     or contains "create entity"): plan starts with
///     `zfa entity create <Name>` then `zfa build`.
///   - **CRUD / use-case behavior** (description contains "crud",
///     "use case", "use-case", "repository", or "service"): plan is
///     `zfa make <slug> --preset=...` then `zfa build`.
///   - Every expressible plan terminates in a `build` step
///     (T005 / U5): build is the only step that produces
///     compile-validated output.
///   - Behaviors whose description names a capability the pipeline
///     does not expose (e.g. "parse bespoke syntax", "wire custom
///     DSL") → `unexpressible` with a reason phrased in behavior
///     terms, naming the unmet capability (FR-005, SC-005).
///
/// The planner is pure: it takes the artifact registry record (or a
/// summary view of it) and returns a plan. It never reads or writes
/// files, never invokes subprocesses. That keeps it unit-testable and
/// keeps the audit trail honest (FR-006 — every actual invocation is
/// captured by the [PipelineRunner], never the planner).
library;

import '../models/artifact_record.dart';
import '../models/generation_plan.dart';

/// Behavior summary the planner consumes. Mirrors just enough of an
/// [ArtifactRecord] to derive a plan; tests construct these directly
/// so the planner stays pure.
class BehaviorSummary {
  final String behaviorId;
  final String feature;
  final String sourceCriterion;

  /// Lowercased human description, e.g. "create entity User with email".
  final String description;

  /// The target / subject name parsed from the description, if any
  /// (used as the entity slug or preset target).
  final String? target;

  const BehaviorSummary({
    required this.behaviorId,
    required this.feature,
    required this.sourceCriterion,
    required this.description,
    this.target,
  });

  /// Construct a summary from a registry record.
  factory BehaviorSummary.fromRecord(
    ArtifactRecord record, {
    String? description,
    String? target,
  }) {
    return BehaviorSummary(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      description: description ?? record.behaviorId,
      target: target,
    );
  }
}

class GenerationPlanner {
  const GenerationPlanner();

  /// Plan the minimal generation for [summary].
  ///
  /// Returns a [GenerationPlan] that is either expressible (steps
  /// non-empty, ending in `build`) or unexpressible (carries a reason
  /// phrased in behavior terms).
  GenerationPlan plan(BehaviorSummary summary) {
    final desc = summary.description.toLowerCase();

    // 1. Entity-bearing behavior: first step is `entity create <Name>`.
    //    Match the words "create entity" or "entity ... with" — both
    //    carry the semantic "the behavior requires a new entity".
    if (desc.contains('create entity') ||
        desc.contains('entity') && desc.contains('with')) {
      final name =
          summary.target ??
          _extractEntityName(summary.description) ??
          'Entity${summary.behaviorId.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')}';
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          GenerationStepSpec(
            // Bug #609: the real EntityCommand requires `-n/--name` and
            // rejects a bare positional name ("Error: Entity name is
            // required. Use -n or --name to specify."). Emit the flag
            // exactly as the real CLI parses it; the slow-tier
            // generation_planner_real_cli_test.dart guards this argv
            // against the real `bin/zfa.dart` so fake-zfa drift cannot
            // regress it.
            args: ['entity', 'create', '-n', name],
            purpose: 'create entity $name for behavior ${summary.behaviorId}',
          ),
          GenerationStepSpec(
            args: ['build'],
            purpose: 'build generated code for behavior ${summary.behaviorId}',
          ),
        ],
      );
    }

    // 2. CRUD / use-case / repository / service behavior: plan is
    //    `make <slug>` (the make preset generates the use-case /
    //    repository scaffolds) then `build`.
    if (desc.contains('crud') ||
        desc.contains('use case') ||
        desc.contains('use-case') ||
        desc.contains('usecase') ||
        desc.contains('repository') ||
        desc.contains('service')) {
      final slug =
          summary.target ??
          _slugify(summary.behaviorId) ??
          'feature_${summary.behaviorId}';
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          GenerationStepSpec(
            args: ['make', slug],
            purpose:
                'generate use-case/repository scaffolds for $slug '
                '(behavior ${summary.behaviorId})',
          ),
          GenerationStepSpec(
            args: ['build'],
            purpose: 'build generated code for behavior ${summary.behaviorId}',
          ),
        ],
      );
    }

    // 3. Misfire: no pipeline mapping. Phrase the reason in behavior
    //    terms and name the unmet capability (SC-005).
    final reason = _unexpressibleReason(summary);
    return GenerationPlan(
      behaviorId: summary.behaviorId,
      feature: summary.feature,
      sourceCriterion: summary.sourceCriterion,
      steps: const [],
      unexpressibleReason: reason,
    );
  }

  /// Extract the entity name from a description like
  /// "create entity User with email" → "User".
  String? _extractEntityName(String description) {
    final m = RegExp(r'entity\s+([A-Z][A-Za-z0-9_]*)').firstMatch(description);
    if (m != null) return m.group(1);
    final m2 = RegExp(r'create\s+([A-Z][A-Za-z0-9_]*)').firstMatch(description);
    return m2?.group(1);
  }

  /// Slugify a behavior id (e.g. "B-001" → "b_001").
  String? _slugify(String id) {
    if (id.isEmpty) return null;
    final buf = StringBuffer();
    for (final ch in id.toLowerCase().runes) {
      if ((ch >= 0x30 && ch <= 0x39) || // 0-9
          (ch >= 0x61 && ch <= 0x7a) || // a-z
          ch == 0x5f) {
        buf.writeCharCode(ch);
      } else if (ch == 0x2d) {
        // dash → underscore
        buf.writeCharCode(0x5f);
      }
    }
    final s = buf.toString();
    return s.isEmpty ? null : s;
  }

  /// Phrase the unexpressible reason in behavior terms (SC-005).
  String _unexpressibleReason(BehaviorSummary summary) {
    return 'behavior "${summary.behaviorId}" requires an implementation '
        'the zuraffa generation pipeline cannot express: no generator '
        'surface maps the behavior description '
        '"${summary.description}" to a `zfa entity create` / `zfa make` '
        '/ `zfa build` invocation. File a zuraffa gap per the STOP-ON-'
        'ROADBLOCK policy.';
  }
}
