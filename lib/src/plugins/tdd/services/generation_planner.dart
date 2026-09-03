/// `GenerationPlanner` — maps a behavior row to a minimal ordered
/// [GenerationPlan] (spec 047-tdd-make T005; FR-005; data-model.md).
///
/// The planner is the command's behavior→pipeline translation layer.
/// It is the SOLE place where a behavior's required generation steps
/// are derived; every other component consumes the plan it produces.
///
/// Mapping rules (minimal generation — FR-005; bug #657 function
/// surface; bug #718 unit-kind dispatch):
///   - **Unit-kind behavior** (bug #718: the id carries the kind —
///     SpecParser emits `U<n>` for FR-derived unit behaviors): plan is
///     `zfa tdd func <id>` (the plain-function generator surface that
///     implements the behavior's no-argument subject function), then
///     `zfa build`. Kind dispatch takes precedence over every
///     description-keyed rule below: a unit behavior's paired artifacts
///     are a plain function + test (spec 044), so entity/CRUD scaffolds
///     can never flip its test green — dispatching on description prose
///     produced `zfa make u5` (the slugified id as an entity name) and
///     the issue #718 generation-error.
///   - **Widget-kind behavior** (issue #950): the row declares kind
///     `widget` (bug #830) — plan is `unexpressible` naming the tdd view
///     lane, so make's composition fallback routes it to the #939
///     view-builder generation (`tdd view <id>` + build). Kind outranks
///     prose and the id-prefix dispatch: `render` in
///     `functionIntentVerbs` must never send a widget row to `tdd func`.
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
///     run. Issue #873: the behavior's OWN id is never a derived
///     name — the generated test name (`<id> — <description>`) that leaks
///     into description-keyed callers must never read as a spec-named
///     entity, or the acceptance path dispatches `zfa make <BehaviorId>`
///     (the #696 family, without `--no-entity`).
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
import '../models/routing.dart';
import 'routing_resolver.dart';

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

  /// Bug #829: the spec Key Entity this behavior's FR traces to (the
  /// declared entity named in the behavior's description), resolved by
  /// the make command against the test list's Key entities section.
  /// Non-null routes a UNIT behavior to the entity pipeline
  /// (entity create -> make <Entity> -> wire -> build) instead of the
  /// plain-function surface, so the domain layer is generated instead
  /// of an empty subject that sidesteps the architecture.
  final String? entityTraced;

  /// The loop kind declared by the feature's test-list row, when the row
  /// is readable (bug #835). Null when unknown — every pre-#835 summary
  /// The loop kind declared by the feature's test-list row, when the row
  /// is readable (bug #835). Null when unknown — every pre-#835 summary
  /// is kindless and keeps routing exactly as before; only `ffi` carries
  /// routing semantics (see [GenerationPlanner.plan]).
  final BehaviorKind? kind;

  /// Whether to demote to shallow func-stubs (the legacy escape hatch).
  final bool stub;

  /// Feature 071: the behavior's raw trace tokens (the test-list row's
  /// `traces` cell) — the resolver resolves these against declared
  /// contract rows.
  final List<String> traces;

  /// Feature 071: the spec's parsed declarations. Null = the caller
  /// cannot supply them and the planner routes the legacy
  /// description-keyed way (fallback window). Non-null: the resolver
  /// decides first; the branches below become the labeled fallback.
  final SpecDeclarations? declarations;

  /// Feature 071: strict mode — undeclared routing intent refuses
  /// instead of falling back (the declaration ladder's strict gate).
  final bool strictRouting;

  const BehaviorSummary({
    required this.behaviorId,
    required this.feature,
    required this.sourceCriterion,
    required this.description,
    this.target,
    this.entityTraced,
    this.kind,
    this.stub = false,
    this.traces = const [],
    this.declarations,
    this.strictRouting = false,
  });

  /// Construct a summary from a registry record.
  factory BehaviorSummary.fromRecord(
    ArtifactRecord record, {
    String? description,
    String? target,
    String? entityTraced,
    BehaviorKind? kind,
    bool stub = false,
    List<String> traces = const [],
    SpecDeclarations? declarations,
    bool strictRouting = false,
  }) {
    return BehaviorSummary(
      behaviorId: record.behaviorId,
      feature: record.feature,
      sourceCriterion: record.sourceCriterion,
      description: description ?? record.behaviorId,
      target: target,
      entityTraced: entityTraced,
      kind: kind,
      stub: stub,
      traces: traces,
      declarations: declarations,
      strictRouting: strictRouting,
    );
  }
}

class GenerationPlanner {
  const GenerationPlanner();

  /// The unit-behavior id encoding (`U<n>`) SpecParser emits for
  /// FR-derived unit behaviors — the kind discriminator unit dispatch
  /// keys on (bug #718).
  static final RegExp _unitBehaviorId = RegExp(r'^U\d+$');

  /// The acceptance-behavior id encoding (`A<n>`) SpecParser emits for
  /// acceptance scenarios (issue #758: the kind discriminator for the
  /// CRUD-branch subject-wiring rule).
  static final RegExp _acceptanceBehaviorId = RegExp(r'^A\d+$');

  /// Whether [behaviorId] is a unit-kind behavior id (the `U<n>`
  /// encoding SpecParser emits for FR-derived unit behaviors; `A<n>` is
  /// the acceptance encoding and dashed ids like `U-6` are legacy
  /// dialects that keep description-keyed routing).
  static bool isUnitBehaviorId(String behaviorId) =>
      _unitBehaviorId.hasMatch(behaviorId);

  /// Whether [behaviorId] is an acceptance-kind behavior id (the `A<n>`
  /// encoding SpecParser emits for acceptance scenarios).
  static bool isAcceptanceBehaviorId(String behaviorId) =>
      _acceptanceBehaviorId.hasMatch(behaviorId);

  /// Plan the minimal generation for [summary].
  ///
  /// Returns a [GenerationPlan] that is either expressible (steps
  /// non-empty, ending in `build`) or unexpressible (carries a reason
  /// phrased in behavior terms).
  GenerationPlan plan(BehaviorSummary summary) {
    final desc = summary.description.toLowerCase();

    // Feature 071 (issue #951): the declaration ladder decides first
    // when the caller supplied parsed declarations. A declared surface
    // yields the plan outright; a declared refusal yields an honest
    // unexpressible plan carrying the resolver's fix-naming message;
    // `undeclared` falls through to the branches below, which are the
    // LABELED fallback (migration window). Callers that supply no
    // declarations keep the exact legacy routing.
    final declarations = summary.declarations;
    if (declarations != null) {
      final result = const RoutingResolver().resolve(
        row: RoutingRow(
          behaviorId: summary.behaviorId,
          kind: summary.kind,
          traces: summary.traces,
        ),
        declarations: declarations,
        strict: summary.strictRouting,
      );
      final declared = _declaredPlan(summary, result);
      if (declared != null) return declared;
    }

    // 0. Native-boundary behavior (bug #835): the test-list row declares
    //    kind `ffi` — the subject is a binding-contract harness wired to
    //    the production native library by hand. The Dart generation
    //    pipeline has no surface for native work (DynamicLibrary symbol
    //    resolution, marshalling adapters, golden recording), and routing
    //    the row anywhere else misfires: a `U<n>` id would hit `tdd func`,
    //    whose scaffold refuses the harness shape, and the run would
    //    dead-end in a generation-error. The honest plan is NONE: the
    //    loop keeps gating on the contract lane (honest red until wired)
    //    and the golden fixture lane keeps gating CI; make reports
    //    unexpressible and the driver defers (bug #625 semantics).
    if (summary.kind == BehaviorKind.ffi) {
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: const [],
        unexpressibleReason:
            'ffi/native-boundary behavior "${summary.behaviorId}" — the '
            'binding implementation is native work (DynamicLibrary symbol '
            'resolution, marshalling adapters) the generation pipeline '
            'cannot express. Wire the production binding into the '
            'behavior\'s subject harness (the symbolResolved / roundTrip / '
            'convertGolden seams) and record the golden fixtures; the '
            'contract lane keeps gating the loop and the golden fixture '
            'lane keeps gating `dart test --preset=integration` in CI.',
      );
    }

    // 0b. Widget-kind behavior (issue #950): the test-list row declares
    //    kind `widget` — the bug #830 testWidgets lane. Kind must
    //    outrank prose (the same principle the #835 ffi guard applies):
    //    `functionIntentVerbs` contains `render`, so a description like
    //    "the widget renders 'Hello, shopper'" would otherwise take the
    //    function-intent branch below and dispatch `tdd func`, whose
    //    scaffold refuses the gen-shaped view-builder stub and dead-ends
    //    the make in a generation-error — with the #939 view lane
    //    unreachable, because it lives in the composition fallback that
    //    only engages on an unexpressible plan. The honest primary plan
    //    is NONE: make's fallback routes widget rows to the view-builder
    //    lane (`tdd view <id>` + build) regardless of the description's
    //    verbs, the id prefix, or CRUD/entity prose.
    if (summary.kind == BehaviorKind.widget) {
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: const [],
        unexpressibleReason:
            'widget-kind behavior "${summary.behaviorId}" — the scenario '
            'is UI-observable and its gen pair is a view-builder subject '
            '+ a testWidgets test, which no primary plan surface '
            'expresses. The make composition fallback routes this row to '
            'the tdd view lane (issue #939): `zfa tdd view '
            '${summary.behaviorId} --feature ${summary.feature}` + build '
            'generates the deterministic minimal view from the declared '
            'Presentation layer contract. A function-intent verb in the '
            'description ("renders") must never route a widget row to '
            '`tdd func` (issue #950 — the func scaffold refuses the '
            'view-builder stub shape).',
      );
    }

    // 1. Unit-kind behavior (bug #718): the behavior id prefix IS the
    //    kind — SpecParser emits `U<n>` for FR-derived unit behaviors
    //    and `A<n>` for acceptance scenarios. A unit behavior's paired
    //    artifacts are a plain no-argument subject function and its
    //    test (spec 044), so the ONLY generator surface that can flip
    //    its test green is the plain-function generator (`tdd func`,
    //    bug #657/#660). Dispatching on the description instead let
    //    entity/CRUD keyword prose win and produced `zfa make u5` —
    //    the slugified behavior id as an entity name — whose scaffolds
    //    can never satisfy a plain-function test (issue #718's
    //    generation-error at U5:make). Kind dispatch therefore takes
    //    precedence over every description-keyed branch below; legacy
    //    dashed ids (`U-6`) and acceptance ids keep their existing
    //    routing.
    if (isUnitBehaviorId(summary.behaviorId)) {
      // Bug #829: a unit behavior whose FR traces to a spec Key Entity
      // routes to the ENTITY pipeline — the same #609/#610 contract the
      // acceptance CRUD branch uses, plus the `make <Entity>` step the
      // issue names (usecases/repos/di — the domain layer the loop must
      // generate instead of an empty func subject). The `entity create`
      // step is realized idempotently by make (an existing entity is
      // reused, never regenerated).
      final traced = summary.entityTraced;
      if (traced != null && traced.isNotEmpty) {
        if (!summary.stub) {
          return GenerationPlan(
            behaviorId: summary.behaviorId,
            feature: summary.feature,
            sourceCriterion: summary.sourceCriterion,
            steps: [
              GenerationStepSpec(
                args: ['entity', 'create', '-n', traced],
                purpose:
                    'ensure entity $traced exists for behavior '
                    '${summary.behaviorId} (idempotent — an existing '
                    'entity is reused, never overwritten)',
              ),
              GenerationStepSpec(
                args: ['mock', 'create', '--name', traced],
                purpose:
                    'generate contract-conforming mock datasource for entity '
                    '$traced (behavior ${summary.behaviorId})',
              ),
              GenerationStepSpec(
                args: [
                  'tdd',
                  'wire',
                  summary.behaviorId,
                  '--entity',
                  traced,
                  '--feature',
                  summary.feature,
                ],
                purpose:
                    'wire subject of behavior ${summary.behaviorId} to '
                    'mock entity $traced',
              ),
              GenerationStepSpec(
                args: ['build'],
                purpose:
                    'build generated code for behavior ${summary.behaviorId}',
              ),
            ],
          );
        }
        return GenerationPlan(
          behaviorId: summary.behaviorId,
          feature: summary.feature,
          sourceCriterion: summary.sourceCriterion,
          steps: [
            GenerationStepSpec(
              args: ['entity', 'create', '-n', traced],
              purpose:
                  'ensure entity $traced exists for behavior '
                  '${summary.behaviorId} (idempotent — an existing '
                  'entity is reused, never overwritten)',
            ),
            GenerationStepSpec(
              args: ['make', traced],
              purpose:
                  'generate the use-cases/repositories/DI for entity '
                  '$traced (behavior ${summary.behaviorId})',
            ),
            GenerationStepSpec(
              // Bug #877: propagate --feature (same ambiguity class as
              // the func/entity wire spawns).
              args: [
                'tdd',
                'wire',
                summary.behaviorId,
                '--entity',
                traced,
                '--feature',
                summary.feature,
              ],
              purpose:
                  'wire subject of behavior ${summary.behaviorId} to '
                  'entity $traced',
            ),
            GenerationStepSpec(
              args: ['build'],
              purpose:
                  'build generated code for behavior ${summary.behaviorId}',
            ),
          ],
        );
      }
      return _functionSurfacePlan(
        summary,
        functionIntentVerb(desc) ?? 'plain-function',
      );
    }

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
            // Bug #877: the behavior-id-resolving spawns carry
            // `--feature` — in a multi-feature project a bare id like
            // `U1` is ambiguous (registered in several features) and
            // `zfa tdd func`/`tdd wire` exit 1, killing the make. The
            // plan's `summary.feature` is the canonical feature the
            // record was generated under (gen stamps `ArtifactRecord
            // .feature`), so propagation is always exact.
            args: [
              'tdd',
              'wire',
              summary.behaviorId,
              '--entity',
              name,
              '--feature',
              summary.feature,
            ],
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
    //
    //    Issue #758: for ACCEPTANCE-kind rows (`A<n>`) the plain
    //    `make` + `build` plan can never flip the target green — CRUD
    //    scaffolds alone never implement the gen'd acceptance subject,
    //    so `make` ended with a mid-run `generation-error` after RED
    //    had already been verified. When the description names an
    //    entity, the plan follows the entity branch's #609/#610
    //    contract: `entity create -n <Name>` first (idempotent — safe
    //    when the entity already exists, and required because the real
    //    `zfa make` fail-fasts on a missing entity source file), then
    //    `make`, then the subject-implementation step (`tdd wire <id>
    //    --entity <Name>`), then `build`. When no entity is
    //    named, the plan fails fast as unexpressible (option (b) of
    //    the issue) with an actionable reason — which also lets
    //    `make`'s composition fallback (#642) engage for features
    //    holding composable green unit subjects. Legacy dashed ids
    //    keep the plain CRUD contract untouched.
    //
    //    Issue #873: the extraction must also refuse the behavior's OWN
    //    id — the generated test name (`<id> — <description>`) callers
    //    pass as the description made the leading id token resolve as
    //    the "named entity" and dispatched `zfa make A3` (no
    //    `--no-entity`, since a non-null derived name drops it): the
    //    #696 family on the acceptance path. The id is filtered inside
    //    `_extractCapitalizedTrace`, and make strips the test-name
    //    prefix before the planner ever sees the description.
    if (desc.contains('crud') ||
        desc.contains('use case') ||
        desc.contains('use-case') ||
        desc.contains('usecase') ||
        desc.contains('repository') ||
        desc.contains('service')) {
      final derivedName =
          summary.target ??
          _extractEntityName(summary.description) ??
          (isAcceptanceBehaviorId(summary.behaviorId)
              ? _extractCapitalizedTrace(
                  summary.description,
                  behaviorId: summary.behaviorId,
                )
              : null);
      final slug =
          derivedName ??
          _slugify(summary.behaviorId) ??
          'feature_${summary.behaviorId}';

      if (isAcceptanceBehaviorId(summary.behaviorId) && derivedName == null) {
        return GenerationPlan(
          behaviorId: summary.behaviorId,
          feature: summary.feature,
          sourceCriterion: summary.sourceCriterion,
          steps: const [],
          unexpressibleReason:
              'acceptance behavior "${summary.behaviorId}" routes to the '
              'CRUD/use-case surface ("${summary.description}") but names '
              'no entity: CRUD scaffolds alone cannot implement the '
              'acceptance subject, so the run would dead-end in a '
              'generation-error. Name the entity in the description '
              '(e.g. "the <Entity> repository service ...") so the plan '
              'can wire the subject with `tdd wire '
              '${summary.behaviorId} --entity <Name>`, or add a green '
              'unit behavior for the composition fallback to compose.',
        );
      }

      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: [
          if (isAcceptanceBehaviorId(summary.behaviorId) && derivedName != null)
            GenerationStepSpec(
              // Issue #758: the real `zfa make` fail-fasts on a missing
              // entity source file (#496), so the entity must exist before
              // the CRUD scaffolds are generated. `entity create` is
              // idempotent, so this is safe whether or not the entity
              // already exists (bug #609: the real CLI requires `-n`).
              args: ['entity', 'create', '-n', slug],
              purpose:
                  'ensure entity $slug exists for behavior '
                  '${summary.behaviorId}',
            ),
          GenerationStepSpec(
            args: derivedName != null
                ? ['make', slug]
                : ['make', slug, '--no-entity'],
            purpose:
                'generate use-case/repository scaffolds for $slug '
                '(behavior ${summary.behaviorId})',
          ),
          if (isAcceptanceBehaviorId(summary.behaviorId) && derivedName != null)
            GenerationStepSpec(
              // Issue #758: implement the acceptance subject against the
              // scaffolds `make` just generated (the #610 wire contract).
              // Bug #877: propagate --feature (see the wire spawn note
              // above) — the same ambiguity class.
              args: [
                'tdd',
                'wire',
                summary.behaviorId,
                '--entity',
                slug,
                '--feature',
                summary.feature,
              ],
              purpose:
                  'wire subject of behavior ${summary.behaviorId} to '
                  'entity $slug',
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
      return _functionSurfacePlan(summary, verb);
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

  /// Translate a resolver outcome into the declared plan, or null when
  /// the ladder leaves the behavior undeclared (the legacy branches
  /// below are then the labeled fallback, migration window).
  GenerationPlan? _declaredPlan(BehaviorSummary summary, RoutingResult result) {
    if (result is RoutingFailure) {
      // Errors-are-an-API: surface the resolver's fix-naming refusal
      // verbatim as the honest plan.
      return GenerationPlan(
        behaviorId: summary.behaviorId,
        feature: summary.feature,
        sourceCriterion: summary.sourceCriterion,
        steps: const [],
        unexpressibleReason: result.message,
      );
    }
    if (result is! RoutingDecision) return null; // RoutingUndeclared
    switch (result.surface) {
      case GenerationSurface.entityPipeline:
        final name = result.entityName;
        if (name == null) return null; // undeclared aspect -> fallback
        return GenerationPlan(
          behaviorId: summary.behaviorId,
          feature: summary.feature,
          sourceCriterion: summary.sourceCriterion,
          steps: [
            GenerationStepSpec(
              args: ['entity', 'create', '-n', name],
              purpose:
                  'ensure entity $name exists for behavior '
                  '${summary.behaviorId} (declared contract row; '
                  'idempotent — an existing entity is reused)',
            ),
            GenerationStepSpec(
              args: ['mock', 'create', '--name', name],
              purpose:
                  'generate contract-conforming mock datasource for entity '
                  '$name (behavior ${summary.behaviorId})',
            ),
            GenerationStepSpec(
              args: [
                'tdd',
                'wire',
                summary.behaviorId,
                '--entity',
                name,
                '--feature',
                summary.feature,
              ],
              purpose:
                  'wire subject of behavior ${summary.behaviorId} to '
                  'declared entity $name',
            ),
            GenerationStepSpec(
              args: ['build'],
              purpose:
                  'build generated code for behavior ${summary.behaviorId}',
            ),
          ],
        );
      case GenerationSurface.plainFunction:
        return _functionSurfacePlan(
          summary,
          result.signature?.name ?? 'declared function',
        );
      case GenerationSurface.viewGeneration:
        // The make composition fallback's widget lane (issue #939)
        // owns view generation — return the honest unexpressible plan
        // that engages it (the #950 widget guard semantics).
        return GenerationPlan(
          behaviorId: summary.behaviorId,
          feature: summary.feature,
          sourceCriterion: summary.sourceCriterion,
          steps: const [],
          unexpressibleReason:
              'widget-kind behavior "${summary.behaviorId}" — the scenario '
              'is UI-observable and its declared contract row routes it to '
              'the tdd view lane (issue #939): `zfa tdd view '
              '${summary.behaviorId} --feature ${summary.feature}` + build.',
        );
      case GenerationSurface.none:
        return GenerationPlan(
          behaviorId: summary.behaviorId,
          feature: summary.feature,
          sourceCriterion: summary.sourceCriterion,
          steps: const [],
          unexpressibleReason:
              'behavior "${summary.behaviorId}" declares a platform-channel '
              'dependency — the native-boundary implementation has no '
              'generation surface (see the ffi contract lane).',
        );
      case GenerationSurface.dependencyMake:
        return null; // not row-declarable yet — legacy fallback decides
      case null:
        return null; // kind declared without a row surface — fallback
    }
  }

  /// The `tdd func` + `build` plan (the bug #657/#660 plain-function
  /// generator surface). Shared by the unit-kind branch (bug #718) and
  /// the function-intent branch (bug #657); [verb] names the described
  /// function intent for the step purpose.
  GenerationPlan _functionSurfacePlan(BehaviorSummary summary, String verb) {
    return GenerationPlan(
      behaviorId: summary.behaviorId,
      feature: summary.feature,
      sourceCriterion: summary.sourceCriterion,
      steps: [
        GenerationStepSpec(
          // Bug #877: the spawn carries `--feature <summary.feature>` —
          // a bare behavior id is ambiguous in multi-feature projects
          // (U1 registered in both 001 and 004 exits 1) and make owns
          // the disambiguated feature.
          args: [
            'tdd',
            'func',
            summary.behaviorId,
            '--feature',
            summary.feature,
          ],
          purpose:
              'scaffold the $verb function for behavior '
              '${summary.behaviorId} from its description',
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

  static const _capitalizedTraceStopwords = {
    'The',
    'A',
    'An',
    'This',
    'That',
    'These',
    'Those',
    'It',
    'Its',
    'Crud',
    'CRUD',
    'Repository',
    'Service',
    'Use',
    'Case',
    'Entity',
  };

  /// Issue #758: acceptance prose often introduces the entity as a
  /// capitalized proper noun mid-sentence — "the Todo repository service
  /// persists a todo item" — where the #696 patterns (`entity <Name>`,
  /// `create <Name>`) cannot match. Return the first such capitalized
  /// word, ignoring articles/demonstratives and the CRUD keywords
  /// themselves. Sentence-initial entity names still resolve (they are
  /// not stoplisted); a capitalized acronym (e.g. "API") can be
  /// extracted, which is benign — the wire step misfire-stops with an
  /// actionable message when no such entity file exists.
  ///
  /// Issue #873: the behavior's OWN id is never an entity name — a
  /// caller may pass the generated test name (`<id> — <description>`)
  /// rather than the bare description, and the leading id token is a
  /// naming convention, not a spec-named entity. Returning it produced
  /// `zfa make A3` (the #696 family on the acceptance path, without
  /// `--no-entity`). The id is filtered case-insensitively, wherever it
  /// appears in the prose; a REAL entity behind the prefix ("A1 — the
  /// Todo repository service ...") still resolves.
  String? _extractCapitalizedTrace(
    String description, {
    required String behaviorId,
  }) {
    final words = description.split(RegExp(r'[^A-Za-z0-9_]'));
    final idLower = behaviorId.toLowerCase();
    for (final word in words) {
      if (word.isEmpty) continue;
      if (!RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(word)) continue;
      if (_capitalizedTraceStopwords.contains(word)) continue;
      // Issue #873: the behavior's own id (the generated test-name
      // prefix) is a naming convention, never a spec-named entity.
      if (word.toLowerCase() == idLower) continue;
      return word;
    }
    return null;
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
