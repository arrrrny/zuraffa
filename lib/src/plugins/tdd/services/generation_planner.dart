/// `GenerationPlanner` — maps a behavior row to a minimal ordered
/// [GenerationPlan] (spec 047-tdd-make T005; FR-005; data-model.md).
///
/// The planner is the command's behavior→pipeline translation layer.
/// It is the SOLE place where a behavior's required generation steps
/// are derived; every other component consumes the plan it produces.
///
/// Mapping rules (minimal generation — FR-005; bug #657 function
/// surface; bug #723 kind-based dispatch):
///   - **Unit-kind behavior** (bug #723: the summary carries
///     `kind: unit` — the test-list row is the source of truth and the
///     `U<n>` id convention the fallback): plan is `zfa tdd func <id>`
///     (the plain-function generator surface from #657/#660 — gen pairs
///     every unit behavior with a no-argument subject stub, and the
///     paired test asserts THAT subject is implemented) then `zfa
///     build`. The kind decides the generator BEFORE any description
///     keyword scan: a unit description carrying entity/use-case
///     vocabulary ("use case returns the count ...") must never route
///     to `zfa entity create` / `zfa make <slugified-id>` — the #723
///     misfire that stopped every run at its first unit behavior.
///   - **Entity-bearing behavior** (description starts with "entity"
///     or contains "create entity"): plan is
///     `zfa entity create -n <Name>` (bug #609: the real CLI requires
///     `-n`), then `zfa tdd wire <id> --entity <Name>` (bug #610: the
///     subject-implementation step — without it green is unreachable
///     with the real pipeline), then `zfa build`.
///   - **CRUD / use-case behavior** (description contains "crud",
///     "use case", "use-case", "repository", or "service"): plan is
///     `zfa make <Name>` then `zfa build`, where `<Name>` is derived
///     from the behavior's trace — the explicit target or a
///     capitalized entity name in the description (bug #696). When the
///     description names no entity, `<Name>` is the slugified behavior
///     id and the plan passes `--no-entity` so the real CLI's #496
///     fail-fast ("no entity source file was found") cannot break the
///     run.
///   - **Function-intent behavior** (bug #657: description carries a
///     plain-function verb phrase — render, format, parse, compute,
///     convert, return — but matches neither surface above): plan is
///     `zfa tdd func <id>` (the plain-function generator surface that
///     derives a return type for the generated no-argument function),
///     then `zfa build`.
///   - Every expressible plan terminates in a `build` step
///     (T005 / U5): build is the only step that produces
///     compile-validated output.
///   - Behaviors whose description names a capability the pipeline
///     does not expose (e.g. "provision bespoke syntax", "wire custom
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
import '../models/behavior.dart';
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

  /// The behavior's loop kind (acceptance vs unit) when the caller
  /// resolved it — the test-list row is the source of truth and the
  /// `A<n>`/`U<n>` id convention the fallback (bug #723). Null keeps the
  /// pre-#723 description-keyed dispatch.
  final BehaviorKind? kind;

  const BehaviorSummary({
    required this.behaviorId,
    required this.feature,
    required this.sourceCriterion,
    required this.description,
    this.target,
    this.kind,
  });

  /// Construct a summary from a registry record.
  factory BehaviorSummary.fromRecord(
    ArtifactRecord record, {
    String? description,
    String? target,
    BehaviorKind? kind,
  }) {
    return BehaviorSummary(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      description: description ?? record.behaviorId,
      target: target,
      kind: kind,
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
    // 0. Kind-based dispatch (bug #723): a unit-kind behavior's
    //    implementation target is its plain-function subject stub, so it
    //    routes to the `tdd func` surface BEFORE the description keyword
    //    scan. Entity/CRUD vocabulary in a unit description ("use case
    //    returns ...", "service exposes ...") must not send the
    //    slugified behavior id to the entity/make generator.
    if (summary.kind == BehaviorKind.unit) {
      return _functionPlan(
        summary,
        functionIntentVerb(summary.description.toLowerCase()),
      );
    }

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
            // Bug #610: the plan previously stopped at `build` — nothing
            // implemented the gen'd subject stub, so green was
            // unreachable with the real pipeline for ANY entity-bearing
            // behavior. The wire step implements the subject against the
            // generated entity (design decision: `zfa tdd wire` — see
            // the command's doc comment and the epic 045 harness spec,
            // precondition 5).
            args: ['tdd', 'wire', summary.behaviorId, '--entity', name],
            purpose:
                'wire subject of behavior ${summary.behaviorId} to '
                'entity $name',
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
    //
    //    Bug #696: the behavior ID is NOT an entity name — a slugified
    //    id (`U5` → `u5`) handed to the real `zfa make` fail-fasts with
    //    "no entity source file was found" (#496). The entity name is
    //    therefore derived from the behavior's own trace first — the
    //    explicit target, then a capitalized name carried by the
    //    description — and ONLY when the description names no entity at
    //    all does the plan fall back to the slugified id, passing
    //    `--no-entity` so the real CLI accepts it.
    if (desc.contains('crud') ||
        desc.contains('use case') ||
        desc.contains('use-case') ||
        desc.contains('usecase') ||
        desc.contains('repository') ||
        desc.contains('service')) {
      final derivedName =
          summary.target ?? _extractEntityName(summary.description);
      final slug =
          derivedName ??
          _slugify(summary.behaviorId) ??
          'feature_${summary.behaviorId}';
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          GenerationStepSpec(
            args: derivedName != null
                ? ['make', slug]
                : ['make', slug, '--no-entity'],
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

    // 3. Function-intent behavior (bug #657): a description whose verb
    //    phrase names a plain function — rendering, formatting, parsing,
    //    computing, converting, returning a value — maps to the `tdd
    //    func` generator surface. The entity and CRUD/use-case branches
    //    above keep precedence, so a description like "create entity
    //    Invoice with totals to render" still maps to `entity create`.
    final verb = functionIntentVerb(desc);
    if (verb != null) {
      return _functionPlan(summary, verb);
    }

    // 4. Misfire: no pipeline mapping. Phrase the reason in behavior
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

  /// The plain-function generator plan (`tdd func <id>` then `build`)
  /// — the #657/#660 surface, reached two ways: description-keyed (a
  /// function-intent verb) and kind-keyed (bug #723: a unit-kind
  /// behavior, whatever its description says). [verb] is the matched
  /// function-intent verb when the description carried one.
  GenerationPlan _functionPlan(BehaviorSummary summary, String? verb) {
    return GenerationPlan(
      behaviorId: summary.behaviorId,
      feature: summary.feature,
      sourceCriterion: summary.sourceCriterion,
      steps: [
        GenerationStepSpec(
          args: ['tdd', 'func', summary.behaviorId],
          purpose: verb != null
              ? 'scaffold the $verb function for behavior '
                    '${summary.behaviorId} from its description'
              : 'scaffold the plain-function subject of unit behavior '
                    '${summary.behaviorId} (kind-based routing, bug #723)',
        ),
        GenerationStepSpec(
          args: ['build'],
          purpose: 'build generated code for behavior ${summary.behaviorId}',
        ),
      ],
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

  /// The plain-function intent verb carried by a lowercased behavior
  /// description, or null when the description carries none (bug #657).
  ///
  /// Verb stems match their inflections (render/renders/rendered/...
  /// return/returns/returned/...) so prose like "render returns a
  /// non-empty string" or "returns 42 when invoked" resolves to the
  /// function surface.
  static const Set<String> functionIntentVerbs = {
    'render',
    'format',
    'parse',
    'compute',
    'convert',
    'return',
  };

  static final RegExp _functionVerb = RegExp(
    '\\b(${functionIntentVerbs.join('|')})(s|ed|ing)?\\b',
  );

  /// Returns the recognized function-intent verb found anywhere in
  /// [description], or null when the planner has no matching function surface.
  static String? functionIntentVerb(String description) {
    final m = _functionVerb.firstMatch(description.toLowerCase());
    return m?.group(1);
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
