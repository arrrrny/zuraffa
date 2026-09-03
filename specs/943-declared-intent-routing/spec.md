# Feature Specification: Declared-Intent Routing (eliminate keyword-based matching)

**Feature Branch**: `943-declared-intent-routing`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/951 — [VISION] eliminate keyword-based matching: route on declared intent (contracts/traces/lane markers), not prose verbs. #936/#950/#920/#696 are one defect class."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Scenario lanes route from declarations, not verbs (Priority: P1)

A spec author declares, per scenario, which declared artifact the scenario exercises — an explicit scenario-type marker, and/or the scenario's trace to a declared layer-contract row (a presentation-contract row declares a UI lane; domain/data-contract rows declare a unit lane; a declared platform-channel dependency declares the native-boundary lane). The behavior pipeline classifies every scenario's lane exclusively from these declarations. Scenario wording — verb choice, tense, phrasing — has zero influence on lane classification.

**Why this priority**: This deletes the highest-frequency failure class reported this week: scenarios misrouted because their prose contained a routing verb in the wrong form (#936 past-tense "rendered"/"navigated" silently weakening suites) or a func-intent verb that hijacked widget rows into the plain-function generator (#950, `generation-error` dead-ends). Lane misrouting is silent or fatal, and authors cannot work around it without gaming their own prose.

**Independent Test**: Can be fully tested by taking a spec whose scenarios contain routing verbs in every tense and confirming each scenario's lane equals the lane its declarations name, regardless of wording — and that rewording a scenario (tense, synonym, phrasing) leaves its routed lane byte-identical. Delivers: authors write natural scenarios without checking which verb the machine will match.

**Acceptance Scenarios**:

1. **Given** a scenario declared as a UI-scenario (marker or presentation-contract trace) whose text contains "renders", "rendered", "returns", or any other function-intent verb, **When** the pipeline classifies the behavior, **Then** the scenario routes to the UI lane — never to the plain-function generator.
2. **Given** a scenario declared as a unit scenario whose text coincidentally contains "renders the formatted report", **When** the pipeline classifies the behavior, **Then** the scenario routes to the unit lane.
3. **Given** a scenario tracing to a declared platform-channel dependency, **When** the pipeline classifies the behavior, **Then** the scenario routes to the native-boundary lane without consulting its prose.
4. **Given** two specs with identical declarations but different prose wording, **When** both are classified, **Then** every routing decision is identical between them.
5. **Given** a scenario whose declaration and whose prose would disagree (e.g. declared UI lane, prose says "returns"), **When** the pipeline classifies the behavior, **Then** the declaration wins and the disagreement is visible in the routing provenance, not silently resolved.

---

### User Story 2 - Generation surface and signatures come from declared contract rows (Priority: P2)

When the pipeline plans generation for a behavior, the surface it picks (which generator lane: entity pipeline, dependency-backed make, view generation, plain-function) and the behavior subject's expected signature (its declared return type) are read from the behavior's trace to a declared contract row — never inferred from description prose. A behavior tracing to an entity contract row plans the entity pipeline; one tracing to a dependency row plans the dependency-backed make; one tracing to a presentation row plans view generation; one tracing to a function contract row plans the plain-function surface with the row's declared signature.

**Why this priority**: Prose-inferred signatures produced vacuous greens (#920: an entity-fields requirement wired to a hardcoded `return 0` subject because no declared signature existed to read), and prose-derived entity naming required a steadily growing patch lineage (#696/#873). Wrong signatures are worse than dead-ends: the suite goes green while measuring nothing.

**Independent Test**: Can be fully tested by writing specs whose contract rows declare unambiguous surfaces and signatures, then confirming each planned surface and subject signature equals the declared one — including a case where the description's verbs would have inferred a different, wrong surface under the old matching. Delivers: generated subjects that are born with the signature the contract promises.

**Acceptance Scenarios**:

1. **Given** a behavior tracing to a declared entity contract row, **When** generation is planned, **Then** the entity pipeline is planned regardless of the description's verbs.
2. **Given** a behavior tracing to a declared function contract row carrying an explicit signature, **When** the subject is generated, **Then** the subject carries that declared signature (no default-integer placeholders born from absent inference).
3. **Given** a behavior whose description contains no recognizable naming signal but whose trace names its contract row, **When** generation is planned, **Then** the plan resolves the correct target from the declaration alone.
4. **Given** a legacy description-keyed fallback must engage because no declaration exists, **When** it does, **Then** the routing provenance names the fallback explicitly, including the spec line that would have declared the intent.

---

### User Story 3 - Persistence marking is declared, not sniffed (Priority: P3)

A requirement carries its persistence intent explicitly — a persistence tag on the requirement or a trace to a declared storage dependency. The pipeline marks persistence behavior from that declaration only. Wording of the requirement ("stores", "saves", "caches", or any storage word) never triggers or suppresses persistence marking.

**Why this priority**: Keyword persistence marking was false-positive-prone by construction (#833), silently changing the generated test harness (fresh-storage boxes, injected clocks) for requirements that merely mentioned a storage word.

**Independent Test**: Can be fully tested by pairing requirements that mention storage vocabulary without declaring persistence (must NOT be marked) against requirements that declare persistence without storage vocabulary (MUST be marked). Delivers: persistence harnesses appear exactly where authors declare them.

**Acceptance Scenarios**:

1. **Given** a requirement with an explicit persistence declaration, **When** the test list is produced, **Then** the behavior carries the persistence mark regardless of wording.
2. **Given** a requirement whose text says "caches the result for display" with no persistence declaration, **When** the test list is produced, **Then** the behavior is NOT marked persistent.
3. **Given** a requirement tracing to a declared storage dependency, **When** the test list is produced, **Then** the behavior carries the persistence mark.

---

### User Story 4 - Routing provenance is visible per behavior (Priority: P4)

For every behavior in a produced plan, the pipeline reports how it routed: the lane chosen, the generation surface chosen, the persistence marking, and — for each — the declaration (or declared fallback rule) it consulted, named in author-readable terms (e.g. "UI lane — presentation contract row: Login page"). An author can read the provenance and find the exact spec line responsible for each decision.

**Why this priority**: Deterministic routing is only trustworthy if it is inspectable; provenance makes declaration-vs-fallback drift visible immediately instead of surfacing as a downstream misroute (#950's failure was invisible until generation errored).

**Independent Test**: Can be fully tested by producing a plan for a mixed spec and checking every behavior's provenance names a real declaration (or an explicitly-named fallback) that exists in the spec. Delivers: authors audit routing in seconds.

**Acceptance Scenarios**:

1. **Given** a spec with declared behaviors, **When** the plan is produced, **Then** every behavior's routing line names the declaration it consulted.
2. **Given** a behavior routed through the legacy fallback, **When** the plan is produced, **Then** the provenance says "fallback" and names the missing declaration's location in the spec.

---

### User Story 5 - Strict mode: a missing declaration is an error, not a guess (Priority: P5)

Once migration completes, a behavior whose routing intent is not declared fails fast with an author-actionable error that names the spec line and the declaration to add (consistent with the errors-are-an-API contract). Keyword-based fallbacks are removed entirely; the pipeline never guesses from prose.

**Why this priority**: The strict flip is the payoff — it deletes the defect class at the root. It ships last so existing specs migrate through the fallback window first.

**Independent Test**: Can be fully tested by presenting an undeclared behavior in strict mode and confirming the run refuses with a fix-naming error referencing the spec line, and that no prose-based fallback path remains reachable. Delivers: the guarantee that routing can never silently depend on wording again.

**Acceptance Scenarios**:

1. **Given** strict mode and a behavior with no routing declaration, **When** the plan is produced, **Then** the run fails with an error naming the spec line and the declaration to add.
2. **Given** strict mode and the documented failure scenarios of #936/#950/#920/#696/#833, **When** each is replayed, **Then** none can reproduce: every routing decision comes from a declaration or the run refuses.
3. **Given** a fully declared spec, **When** routed in strict mode, **Then** the run behaves identically to the fallback window (no author-visible change).

---

### Edge Cases

- What happens when a behavior's declarations conflict (declared UI lane AND declared entity trace)? The pipeline must refuse with an author-actionable conflict error naming both spec lines — never pick one silently.
- What happens when a declared contract row itself is malformed (missing signature, unknown kind)? The pipeline must refuse naming the contract row, not fall back to prose guessing.
- What happens when a legacy spec (pre-declaration template) is routed during the fallback window? It keeps working with fallback provenance on every behavior, so authors see exactly what to migrate.
- What happens when a scenario's declaration references a contract row that does not exist? The pipeline must refuse naming the dangling reference.
- What happens when a scenario declares a type marker AND a contradicting contract-row trace? Same as conflicting declarations: refuse, name both lines.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The behavior pipeline MUST classify every behavior's lane exclusively from explicit declarations: the scenario's scenario-type marker and/or its trace to a declared contract row. Prose wording MUST NOT influence lane classification.
- **FR-002**: The spec template MUST let authors declare, per scenario, at minimum: the scenario's type (unit, UI, native-boundary) and the contract row it traces to.
- **FR-003**: The spec template's contract sections MUST carry, per row: the row's kind (presentation, domain, data, dependency, function) and, where applicable, its declared signature.
- **FR-004**: The pipeline MUST choose the generation surface (entity pipeline, dependency-backed make, view generation, plain-function) exclusively from the behavior's declared contract-row trace.
- **FR-005**: The pipeline MUST derive generated subject signatures exclusively from declared signatures; it MUST NOT invent return types or parameters from description text.
- **FR-006**: The pipeline MUST mark persistence exclusively from explicit persistence declarations (requirement tags or storage-dependency traces); storage vocabulary in prose MUST NOT trigger marking.
- **FR-007**: The pipeline MUST attribute generation targets (entities, dependencies) exclusively to explicitly declared references; it MUST NOT extract names from description prose or test-name conventions.
- **FR-008**: The pipeline MUST emit routing provenance for every behavior naming the consulted declaration (or the named fallback) in author-readable terms referencing the spec line.
- **FR-009**: During the migration window, the pipeline MAY consult legacy keyword fallbacks ONLY when no declaration exists, and MUST label such routing as fallback in provenance, naming the spec line that would declare the intent.
- **FR-010**: The pipeline MUST support a strict mode in which undeclared routing intent is an error naming the spec line and the declaration to add; in strict mode no prose-based fallback path may be reachable.
- **FR-011**: The pipeline MUST refuse with author-actionable errors (naming the spec lines involved) when declarations conflict, reference nonexistent rows, or are malformed.
- **FR-012**: Structural grammar parsing (scenario headers, section structure, template version, manual markers, behavior id prefixes) MUST be preserved unchanged — this feature eliminates semantic keyword matching over prose, not declared-structure parsing.
- **FR-013**: Rewording a scenario without changing its declarations MUST NOT change any routing decision (lane, surface, signature, persistence marking).

### Key Entities *(include if feature involves data)*

- **Scenario declaration**: per-scenario intent — the declared scenario type and the contract row(s) the scenario traces to; the single authoritative input to lane classification.
- **Contract row**: a declared artifact of the spec's layer contracts — its kind (presentation, domain, data, dependency, function), its identity authors trace to, and where applicable its declared signature.
- **Persistence declaration**: a requirement's explicit statement that it involves persistent storage (tag or storage-dependency trace).
- **Routing provenance**: the per-behavior record of what was consulted — declaration reference or named fallback — for lane, surface, signature, and persistence decisions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Rewording any scenario (verb, tense, synonym, phrasing) with declarations unchanged produces byte-identical routing decisions for 100% of behaviors.
- **SC-002**: Every documented failure shape of #936, #950, #920, #696/#873, and #833, replayed against the new pipeline, fails to reproduce — zero of the five defect classes remain reachable.
- **SC-003**: 100% of routing decisions in a produced plan carry provenance naming a spec line an author can open.
- **SC-004**: In strict mode, 100% of undeclared routing intents produce a refusal naming the spec line and the declaration to add; zero silent guesses remain.
- **SC-005**: A valid legacy spec (no declarations) routes during the fallback window with zero author-visible behavior change except the added fallback provenance.
- **SC-006**: An author reading only the spec (no pipeline knowledge) can predict every routing decision correctly — the spec is the single source of truth.

## Assumptions

- The five defect reports (#936, #950, #920, #696/#873, #833) define the scope of "keyword-based matching" to eliminate; declared-structure parsing (scenario headers, section tables, id prefixes, template markers) is explicitly preserved.
- Migration follows the issue's staged path: template declarations ship first, keyword classifiers are demoted to named fallbacks (FR-009), provenance makes drift visible (FR-008), and the strict flip (FR-010) lands after specs migrate — strict mode default-on is a later decision, not part of the first delivery.
- Exact marker/trace syntax in the spec template is a planning concern; this spec fixes only that declarations must exist, be authoritative, and be line-addressable.
- Existing specs in active projects must keep routing during the migration window (no forced big-bang migration).
- The legacy keyword fallbacks are removed only when strict mode flips; their removal before then would break the migration contract (FR-009).
