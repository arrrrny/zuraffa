# Research: Declared-Intent Routing

Feature: 071-declared-intent-routing (issue #951). All unknowns resolved against the
current codebase inventory (paths/lines verified at HEAD `738b3840`).

## D1 — What counts as a routing declaration, and in what precedence?

**Decision**: A four-rung **declaration ladder**, consulted top-down; the first rung
that applies decides, and every application records provenance.

1. **Scenario type marker** — an explicit per-scenario declaration in the spec
   (`**Type**: widget|unit|ffi|platform|theme|acceptance`, new in template v1.1).
2. **Contract-row trace** — the scenario/FR's trace references a declared contract
   row (Layer Contracts bullet, Key Entities row, or External Dependencies row);
   the row's kind decides (see D2).
3. **Test-list kind declaration** — the existing declared mechanisms: section
   headers (`## Outer loop: widget behaviors`, `## Inner loop: unit behaviors`,
   `## Theme harness`, `## Native loop`, `## Platform harness`) and kind cells.
4. **Named fallback** (migration window only) — the legacy keyword classifiers,
   still consulted when rungs 1–3 yield nothing, but labeled `fallback` in
   provenance with the spec line that would declare the intent. Removed in strict
   mode (D6).

**Rationale**: Rung 3 already exists and is the authoritative kind source for
ffi/theme/platform (test_list_reader.dart:208-240, 537-556) — the feature extends a
working pattern rather than inventing a new one. Rungs 1–2 move declaration upstream
into the spec (the author's single source of truth, SC-006), which is exactly the
#919 precedent (parse declared structures, not prose).

**Alternatives considered**:
- *Test-list-only declarations (rung 3 alone)*: rejected — the test list is
  generated output; authors would hand-maintain generated artifacts and the spec
  would remain ambiguous.
- *Kind cells only (no contract traces)*: rejected — kind says which lane, not
  which surface/entity/signature; FR-004/005/007 need row-level references.
- *Immediate keyword removal (no rung 4)*: rejected by the spec's own migration
  contract (FR-009, SC-005) — existing specs must keep routing.

## D2 — Contract-row kind → lane/surface mapping

**Decision**:

| Declared row (where) | Row kind | Lane (BehaviorKind) | Generation surface |
|---|---|---|---|
| Layer Contracts bullet — `**Presentation**` | presentation | widget | `tdd view <id>` + build |
| Layer Contracts bullet — `**Domain**` / `**Data**` | domain/data | unit | entity pipeline (`entity create` → make/wire → build) |
| Key Entities row | entity | unit | entity pipeline, entity name = declared row name |
| External Dependencies row — storage type | storage | (lane unchanged) | persistence marked (D4) |
| External Dependencies row — channel type | platform | ffi/platform (per existing kind) | native-boundary honest stop / platform lane |
| New `**Function**` contracts bullet | function | unit | `tdd func <id>` with the row's declared signature (D3) |

A scenario tracing to multiple rows of different kinds is a **conflict** (refuse,
FR-011), not a precedence puzzle.

**Rationale**: Mirrors the issue's own replacement table 1:1 (presentation → widget
lane; domain/data → unit; platform dependency → ffi; entity row → entity pipeline;
presentation row → `tdd view`). The function contract row is added so #920/#657's
plain-function surface becomes declarable — otherwise `render`-type behaviors would
have NO legal declaration and the func surface would be unreachable in strict mode.

**Alternatives considered**:
- *Infer surface from row kind with no function rows*: rejected — makes the
  plain-function surface undeclarable and pushes authors to phrase FRs as fake
  entity rows (the #696 trap reborn as a template hole).
- *Let traces to multiple rows compose*: rejected — composition is exactly the
  silent-guessing this feature removes; conflicts must be loud.

## D3 — Declared signatures: format and precedence

**Decision**: Function contract rows carry standard Layer-Contracts signature
syntax: `` `format(Template) -> String` ``. The resolver parses `name(params) -> Return`
(the same shape #919 already parses for repository methods). `zfa tdd func`/`tdd wire`
use the declared return type (and parameter names) for the scaffolded subject;
`deriveSubjectSignature` (subject_signature_deriver.dart:23-96) runs only as the
rung-4 fallback, labeled in provenance.

**Rationale**: The Layer Contracts grammar already exists and is parsed
(spec_parser.dart:275-306) — declaring signatures needs no new syntax. #920's
vacuous-green shape (heuristic picked `int` → `return 0`) becomes impossible when
the row says the return type; the heuristics survive only for legacy specs.

**Alternatives considered**:
- *New signature DSL*: rejected — two grammars for the same thing invites drift.
- *Drop inference immediately*: rejected — breaks the fallback window contract.

## D4 — Persistence declarations

**Decision**: Two declaring forms, either suffices: (a) a `[persistent]` tag on the
FR line (rendered into the test-list row's existing ` [persistence]` mark — the
mark itself is unchanged, only its trigger becomes declarative); (b) a trace to an
External Dependencies row whose declared type is storage (hive/cache/sqlite token
in the type cell). `PersistenceMarker.matchesKeywords` (test_list_reader.dart:135-138)
becomes the rung-4 fallback; `PersistenceMarker.extract` (read side) is untouched —
it parses the declared mark, which is already structure.

**Rationale**: The `[persistence]` mark and its read-side parser exist (#833's
harness contract); only the *trigger* was keyword-based. Declaring via the storage
dependency row reuses the zuraffa-1.0 Dependencies table with zero new syntax.

**Alternatives considered**:
- *Keyword allowlist curated by hand*: rejected — still prose matching, the defect
  class itself.
- *New `## Persistence` section*: rejected — duplicates the dependency table's job.

## D5 — Provenance format

**Decision**: One line per behavior, printed by `zfa tdd plan` (which currently
prints only aggregate counts, plan_command.dart:276-288):

```
   route: A3 -> widget lane (presentation contract: Login page) [declared: type marker, spec line 42]
   route: U2 -> func surface (function contract: Formatter.format -> String) [declared: contract row, spec line 87]
   route: U5 -> unit lane [fallback: keyword 'persist' matched — declare [persistent] on FR-007 (spec line 31)]
```

Machine-parseable tail token `[declared: …]` / `[fallback: …]`; `--strict-routing`
turns the fallback case into a refusal naming the spec line. Provenance is also
written into the test list's traceability block so it outlives the terminal.

**Rationale**: The issue names this exact output shape (`A3 -> widget lane
(presentation contract: Login page)`). Terminal + artifact gives both instant
visibility and a durable audit surface.

**Alternatives considered**:
- *Provenance only in artifacts*: rejected — drift visibility (US4) requires it in
  the author's face at plan time.
- *Verbose multi-line provenance*: rejected — plan output must stay scannable.

## D6 — Strict mode mechanics

**Decision**: `--strict-routing` flag on `zfa tdd plan` (and honored by
`make`'s planner), plus project config opt-in. Default: **off** (migration window
per FR-009/Assumptions). In strict mode, ladder rung 4 is unreachable: undeclared
intent → exit non-zero with `--> fix:` naming the spec line and the declaration to
add (errors-are-an-API).

**Rationale**: The issue's migration path demotes first, flips later; a flag keeps
both worlds runnable and CI can adopt strict per project.

**Alternatives considered**:
- *Strict-on via template version detection alone*: rejected as the sole mechanism —
  version-gated behavior is surprising; the flag makes intent explicit. (Template
  version may later imply strict; that flip is out of scope per spec Assumptions.)

## D7 — Where the resolver lives

**Decision**: New pure service `RoutingResolver` (lib/src/plugins/tdd/services/routing_resolver.dart):
inputs = parsed spec declarations + behavior row; output = `RoutingDecision`
(kind, surface, entity, signature, persistence, provenance lines) or typed
`RoutingFailure` (conflict / dangling / malformed / undeclared-strict). Planner,
plan command, and func/wire signature lookup consume it; the sniffers move behind
rung 4 inside it (or behind the call sites for classifier-specific cases), so the
ladder is testable as one unit.

**Rationale**: Routing is currently smeared across spec_parser (lane),
generation_planner (surface/entity), test_list_reader (persistence), and
subject_signature_deriver (signature). A single pure resolver is unit-testable
(the repo's dominant test idiom), keeps the planner pure by contract, and gives
the provenance one owner.

**Alternatives considered**:
- *Patch each call site inline*: rejected — five scattered ladders would drift
  exactly like the five sniffers did.
- *Resolver reads files itself*: rejected — violates the planner's documented
  purity contract; callers pass parsed declarations.
