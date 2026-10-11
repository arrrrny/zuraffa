---
feature: 1570-make-methods-append-propagate-mock
loop: outside-in
profile: .specify/memory/tdd-profile.md
---

# Test List: 1570-make-methods-append-propagate-mock

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | drifted certified mock (implements `get`, interface declares `get, getList`) + mock lane run (`appendToExisting:false, force:false`) → mock repaired to implement `getList`, ledger action `updated`, repaired member set ⊇ interface member set (SC-001, SC-002). | AC-1 | RED |
| A2 | in-sync mock + same lane run → untouched (`skipped`, bytes identical) — the idempotent-regeneration promise holds (SC-003). | AC-2 | RED |
| A3 | fail-open: interface file missing (or interface class absent / unparseable) → no repair, no exception, skip preserved, mock bytes untouched (FR-004). | AC-3 | RED |
| A4 | honesty: repair notice names the entity + missing member(s) + file; ledger carries `updated`; dry-run leaves bytes unchanged (SC-004). | AC-4 | RED |
| A5 | the drift repair is strictly ADDITIVE (review round): a member the mock already declares — customized body included — is never re-emitted/replaced; only genuinely missing members are appended (FR-005). | AC-2 | RED |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `detectMockStaleness` returns EXACTLY the interface members absent from the mock class; extra mock helpers/getters are neither "missing" nor flagged; empty when in-sync. | FR-003 | RED |
| U2 | synthesized impls for `Future<T>` / `Future<List<T>>` / `Future<void>` / `Stream<T>` members carry the lane's canonical body patterns (`sample<Entity>` / `sampleList` / `Future.value()` / `Stream.fromFuture`) and signatures that MIRROR the interface declaration — parameter-less members carry no `params` argument, the `--init` getter stays a getter, stream bodies delay through `Future<T>` (review round; covers the drift synthesis AND the custom-usecase stream branch) — asserted with a REAL scoped `dart analyze` over the repaired interface + mock pair (`mock_datasource_builder_1570_compile_test.dart`). | FR-002 | RED |
| U3 | a custom-usecase mock member the interface does not declare survives the repair. | FR-002/FR-005 | RED |
| U4 | precedence: `revert` → undo/delete path untouched (no repair); `appendToExisting:true` → existing append path unchanged; `force:true` → regeneration wins, detector never arms. | FR-008 | RED |
| U5 | dry-run: transaction records the repair but the mock file bytes on disk are unchanged. | FR-007 | RED |
| U6 | through `MockPlugin.generate` (the `mock create` config shape): drifted mock on disk heals end-to-end, returned files include the mock with `updated`. | FR-001/FR-006 | RED |
| U7 | repair appends via the existing append executor path — the repaired file keeps its leading provenance comment and prior imports (no format clobber). | FR-002 | RED |
| U8 | no drift outside the mock lane: interface/remote writers' outputs in a make-shaped run are byte-identical before/after the fix (SC-005 regression guard — covered by the unchanged-writer suites staying green, not by a new test file). | FR-008 | GUARD |

## Mutation targets

- `mock_staleness_detector.dart`: drop each fail-open guard (interface
  missing / class missing / mock unparseable) → a test must fail (A3/U1).
- `generateMockDataSource` arming condition: flip any conjunct
  (`appendToExisting`, `force`, `revert`) → U4 or A2 must fail.
- Repair notice: remove the stdout notice → A4 must fail.
