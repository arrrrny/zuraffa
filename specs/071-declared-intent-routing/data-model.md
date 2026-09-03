# Data Model: Declared-Intent Routing

Feature: 071-declared-intent-routing. Entities are spec artifacts and in-memory
routing records; nothing here is persisted beyond the spec/test-list files
themselves.

## Entities

### ScenarioDeclaration

The per-scenario routing intent an author declares in the spec. Extracted by the
parser from scenario bodies and FR lines.

| Field | Type | Source (declared structure) | Notes |
|---|---|---|---|
| behaviorId | String | scenario/FR id (`A<n>`, `U<n>`, legacy dashed) | the behavior the declaration belongs to |
| declaredType | BehaviorKind? | `**Type**: <kind>` marker line in the scenario body | optional; validated against the enum |
| contractRefs | List<String> | trace cell references resolving to contract rows (entity names, contract interface names, dependency names) | **reserved for future use** — never populated by the shipped parser (FR `traces:` continuations are consumed as the U-keyed `parseFrContractTraces` map instead); empty = no row trace |
| specLine | int | position of the marker/trace in spec.md | names the line in provenance and errors |

Validation: declaredType must parse to a BehaviorKind; contractRefs must resolve to
existing rows (else `dangling-reference` failure, FR-011) — no `contractRefs`
validation runs while the field is unpopulated (reserved).

### ContractRow

A declared artifact the declarations can trace to. Already parsed today
(Layer Contracts) or present in the zuraffa-1.0 template (Key Entities, External
Dependencies); the feature adds the function-rows bullet and reads kind/signature
from all of them.

| Field | Type | Source | Notes |
|---|---|---|---|
| name | String | interface/row name (`` `Login page` ``, `ProductRepository`) | the trace target |
| kind | RowKind | derived from the declaring section: presentation / domain / data / entity / storage / channel / function | drives lane + surface mapping (research D2) |
| signatures | List<Signature> | Layer Contracts bullet methods; function-row methods | parsed `name(params) -> Return` |
| specLine | int | row position in spec.md | provenance + errors |

RowKind → lane/surface mapping is a pure function (research D2 table); two rows of
different kinds reachable from one behavior = `declaration-conflict` failure naming
both rows (FR-011).

### Signature

A declared subject signature (subset of a ContractRow's methods relevant to the
behavior).

| Field | Type | Notes |
|---|---|---|
| name | String | e.g. `format` |
| parameters | List<String> | declared parameter types/names |
| returnType | String | e.g. `String`, `Future<Result<void, AppFailure>>` |

Replaces prose inference (FR-005). Malformed signature text (no `->` return) =
`malformed-declaration` failure naming the row (FR-011).

### PersistenceDeclaration

A requirement's explicit persistent-storage intent.

| Field | Type | Source | Notes |
|---|---|---|---|
| behaviorId | String | FR line | |
| source | enum {frTag, storageDependency} | `[persistent]` tag / trace to storage-kind dependency row | provenance names which |
| specLine | int | tag or row position | |

Replaces keyword matching (FR-006). The downstream mark in the test list
(`[persistence]` cell suffix) and the harness contract are unchanged.

### RoutingDecision

The resolver's output for one behavior — everything downstream needs.

| Field | Type | Notes |
|---|---|---|
| behaviorId | String | |
| kind | BehaviorKind | the lane (rung 1–3 decided; rung 4 only in fallback window) |
| surface | GenerationSurface | entityPipeline / dependencyMake / viewGeneration / plainFunction / none-unexpressible |
| entityName | String? | declared entity reference (FR-007); null unless declared |
| signature | Signature? | declared signature (FR-005); null unless declared |
| persistence | bool | decided by PersistenceDeclaration (FR-006) |
| provenance | List<ProvenanceLine> | one per decided aspect (kind, surface, entity, signature, persistence) |

### ProvenanceLine

One author-readable routing justification (FR-008).

| Field | Type | Notes |
|---|---|---|
| aspect | enum {kind, surface, entity, signature, persistence} | which decision it justifies |
| source | enum {declared, fallback} | |
| detail | String | e.g. `presentation contract: Login page (spec line 42)` or `keyword 'persist' matched — declare [persistent] on FR-007 (spec line 31)` |
| specLine | int? | the authoritative or to-be line |

Rendered as `route: <id> -> <decision> [declared: …]` / `[fallback: …]` (research D5).

### RoutingFailure

Typed refusal (errors-are-an-API); never a silent guess.

| code | Meaning | Names |
|---|---|---|
| declaration-conflict | two rungs/rows of different kinds apply | both spec lines |
| dangling-reference | trace names a nonexistent row | the reference + spec line |
| malformed-declaration | unparseable marker/signature/row | the offending text + spec line |
| undeclared-strict | strict mode, no rung 1–3 declaration | spec line + the declaration to add |

## Relationships

- ScenarioDeclaration 1—0..* ContractRow (traces; must resolve, kind-consistent)
- ContractRow 1—0..* Signature (function rows carry them)
- PersistenceDeclaration 1—1 behavior (FR line)
- RoutingDecision 1—1 behavior; aggregates 0..* ProvenanceLine
- RoutingDecision consumed by: generation planner (kind/surface/entity), func/wire
  commands (signature), plan command (persistence + provenance rendering)

## State transitions

None — all entities are immutable per parse; a re-plan rebuilds decisions. The only
transition is the pipeline-level mode: fallback window ⇄ strict (project flag), which
changes ladder reachability (rung 4) and turns `undeclared` from fallback into
`undeclared-strict` failure.
