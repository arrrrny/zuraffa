# Data Model: Dependency-Table Mocks (072)

## Entities

### SpecDependency (existing, consumed)

One declared row of the External Dependencies & Contracts table.

| Field | Type | Notes |
| --- | --- | --- |
| dependency | String | row name, e.g. `FirebaseAuth` |
| type | String | declared kind, e.g. `service`, `storage` |
| contract | String | raw signatures text, e.g. `signIn(email, password) -> User, signOut() -> void` |
| mockPriority | String | `P1`/`P2`/`P3`/empty (unprioritized) |

### DependencyContract (new value object)

The typed read of one row, produced once and shared by routing,
generation, and realize.

| Field | Type | Notes |
| --- | --- | --- |
| name | String | dependency name |
| kind | ContractRowKind | `service` (new) / `storage` (existing mapping) |
| signatures | `List<Signature>` | 071 `Signature` values; empty ⇒ `rawSignatures` carries malformed text |
| rawSignatures | `List<String>` | unparsed cells (lazy-parse refusals name these) |
| priority | MockPriority | `p1`/`p2`/`p3`/`none` |
| specLine | int? | row line in spec.md for refusals |

### MockPriority (new enum)

`p1, p2, p3, none` — parsed case-insensitively from the 4th cell; sort
key `(tier, declarationIndex)` with tiers p1=0, p2=1, p3=2, none=3.

### DependencyMockPlan (new, plan artifact section)

Per-row generation plan rendered into the plan artifact and consumed by
the loop.

| Field | Type |
| --- | --- |
| contract | DependencyContract |
| orderPosition | int (0-based, after priority sort) |
| artifactPath | String (deterministic path under `test/mock/dependencies/` or lib mirror per house layout) |

### DependencyMockArtifacts (new, generated)

| Artifact | Content |
| --- | --- |
| interface | abstract class `<Name>` with exactly the declared methods (params + return types as declared) |
| fake | `<Name>Fake` implements `<Name>`; per-method scriptable response slot; call recorder (method, args, order) |
| fixture | staged scenario fixture(s) for the fixture lane (`spec()` style builders), deterministic content |

Registry record: `behavior_id: dependency:<Name>`,
`source_criterion: <row spec line>`, `test_path`/`subject_path` pointing
at generated artifacts, `runnable_test_name` unset (not a behavior).

### Routing (071 model extensions)

| Change | Where |
| --- | --- |
| `ContractRowKind.service` added | routing.dart |
| dependency rows parsed with signatures + priority | spec_parser.dart |
| traced dependency row ⇒ `surface = dependencyMake`, provenance `dependency <Name> (<type>, priority <Pn>)` | routing_resolver.dart |
| `MockPriority` sort applied to materialization | make_command.dart / generation_planner.dart |

## Invariants

1. I1: generated surface == declared signatures, member-for-member (no
   invented/missing/renamed members).
2. I2: regeneration determinism — same row ⇒ same bytes.
3. I3: a behavior reaches a dependency mock ONLY via a trace to a
   declared row (never prose).
4. I4: every refusal names the row (and spec line when known) plus a
   `--> fix:` hint.
