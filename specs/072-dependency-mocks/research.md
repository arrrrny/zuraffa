# Research: Dependency-Table Mocks (072)

## R1 — Where dependency rows live today

- `SpecParser.parseContractRows` (spec_parser.dart) reads the External
  Dependencies section into `ContractRowDecl`s but **skips** any type that
  is not `storage*` / `channel*`/`platform*` (`if (kind == null) continue`)
  — a `service` row (FirebaseAuth, Vendure) never becomes a declaration.
- Rows carry no signatures: the contract cell (3rd column) is discarded.
- `TestListReader.readDependencies()` returns the raw 4-cell rows
  (`dependency/type/contract/mockPriority`) from the plan artifact — the
  raw material already reaches the loop.

**Decision**: extend the dependency-row branch in `parseContractRows`:
parse the contract cell into `Signature` list (071 grammar
`name(Params) -> Return`, methods separated by `,`), map `service*`
(and any non-storage/channel/non-empty type) to the new
`ContractRowKind.service`, and attach the priority cell. Malformed
signature text is kept in `rawSignatures` for the resolver's
`malformedDeclaration` refusal (071 convention: lazy parse, refusal
names the row).

## R2 — Where the mock generator lives

`zfa mock create` is the mock plugin's `CreateMockCapability`
(`lib/src/plugins/mock/capabilities/`, `ZuraffaCapability` interface:
`name`/`description`/`inputSchema`/execute; builders under
`builders/`). **Decision**: add `DependencyMockCapability` (name
`dependency`, CLI `zfa mock dependency <Name>`) with a pure
`DependencyMockBuilder` that renders the interface + fake + fixture from
a `DependencyContract` value object. Determinism: no timestamps, stable
ordering, single template — the 071/939 lesson (same bytes or it's a
bug).

## R3 — Routing seam

071 already reserved `GenerationSurface.dependencyMake` and routes on
`ContractRowDecl`s via trace tokens (`RoutingResolver.resolve`). Today
no dependency row kind maps to a surface (`_laneFor`/surface switch:
storage → persistence aspect, channel → platform kind; service rows
don't exist). **Decision**: service/storage rows traced by a behavior
resolve `surface = dependencyMake` + `aspect: surface` provenance naming
`<Name> (<type>, priority <Pn>)`. Kind stays unchanged (071 owns lane
classification); this feature owns the surface decision only.

## R4 — Harness wiring + missing-mock refusal

The make path's generation planning (`generation_planner.dart`) emits
per-behavior generation steps. **Decision**: for dependencyMake
behaviors, plan a mock-materialization step for the referenced row
(idempotent: registry record keyed `<feature>/<dependency>`). If the
mock is absent and the loop's generation gate is off, the step refuses
with `--> fix: zfa mock dependency <Name>` (FR-006; errors-are-an-API).

## R5 — Priority ordering

Priority lives in the 4th row cell (P1/P2/P3; case-insensitive; empty →
unprioritized). **Decision**: sort key `(tier, declarationIndex)` with
tier P1=0, P2=1, P3=2, none=3; applied where the make path materializes
dependency mocks and rendered in the plan artifact's dependency section
(order + priority visible — FR-007/SC evidence).

## R6 — Realize parity

`RealizeCommand` runs a contract gate + differential gate for entity
datasource mocks (#913). **Decision**: when the adapter name matches a
declared dependency row, the contract gate loads the row's signatures
and the parity source is the DECLARED contract; a missing/extra/renamed
member refuses naming the member and the row (FR-009 / US4 acceptance
2). Reuses the existing gate plumbing; no new command mode.

## R7 — Alternatives rejected

- **Entity-keyed mock reuse** (`mock create` with a fake entity):
  rejected — invents an entity to describe a dependency; surfaces drift
  from the declared contract and the registry loses provenance.
- **New routing mechanism for dependencies**: rejected — 071's
  declaration ladder is exactly this seam; a parallel mechanism would
  reopen the keyword/prose defect class.
- **Generating from the dependency's real SDK types**: rejected —
  out of scope and undeclared; the contract row is the declared truth
  (VISION §9: the machine certifies against the declared contract).
