---
feature: 1418-mock-force-regen-interface
loop: outside-in
profile: .specify/memory/tdd-profile.md
---

# Test List: 1418-mock-force-regen-interface

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | stale interface (declares `list(NoParams)`) + `MockBuilder.generate` with `force: true, methods: [getList]` → interface regenerated from the current methods: declares `getList(ListQueryParams<Entity>)`, no longer declares `list(NoParams)`, ledger action `overwritten` (SC-001, FR-001). | US1-AC-1 | RED |
| A2 | the force-regenerated pair conforms: interface member set ⊆ mock implemented member set (extraction via the certification's own primitives), missing set empty — the structural gate the certification runs would pass on this pair (SC-001, FR-003). | US1-AC-2 | RED |
| A3 | non-force run on the same drifted tree leaves the interface byte-identical (create-if-absent preserved for the interface writer; mock side keeps the #1570 ledger `updated`) (SC-002, FR-002). | US2-AC-1 | RED |
| A4 | absent interface: force and non-force runs each emit it once (`created`); the mock's import target exists after the run (#417 guarantee) (FR-002). | US1-AC-3, US2-AC-2 | RED |
| A5 | mock-barrel hide semantics (SC-004, FR-004/005): (a) diverged mock barrel (no bare zuraffa re-export) → `filterMock` drops zuraffa-only names while `filter` keeps them; (b) bare re-export present → `filterMock` keeps the zuraffa union (#942 preserved); (c) combinator-carrying (`show`) mock re-export → only shown names union; (d) unresolved surface → both filters return empty (no combinator). | US3-AC-1..3 | RED |
| A6 | emission-level: the generated mock datasource's `package:zuraffa/mock.dart` import carries a `hide` clause containing ONLY mock-barrel-verified names — an entity name absent from the surface never appears in any `hide` (SC-004, FR-004). | US3-AC-1 | RED |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | force + dry-run: no file bytes change anywhere in the tree; the would-be regeneration is visible in the returned ledger (FR-006). | FR-006 | RED |
| U2 | force + revert: the interface regeneration guard does not fire over revert — revert keeps its pre-change contract (FR-007). | FR-007 | RED |
| U3 | `repo: <Entity>Repository` config: the force-regenerated interface lands at the repo-derived path the guard computed (no second interface file) and declares the regenerated members (edge case). | FR-001 | RED |
| U4 | idempotence: two consecutive force runs on the same config produce byte-stable interface AND mock output (SC-003) (edge case). | FR-001 | RED |
| U5 | `filterMock` unit semantics at the resolver level (beyond A5's seeded cases): mock-local declarations along the chain (e.g. a type declared in `src/mock/mock.dart` itself) survive; `package:` targets other than the zuraffa barrel stay excluded; depth-capped chains stop cleanly (FR-004). | FR-004 | RED |
| U6 | `filter` (zuraffa surface) behavior is byte-for-byte unchanged by the mock-surface addition — the existing #1530 suite + #942 suite pass untouched (SC-005 regression guard — covered by the existing suites staying green, not by a new test file). | FR-005 | GUARD |

## Mutation targets

- `mock_builder.dart` guard: flip `config.force` (drop it) → A1 fails;
  drop `!config.revert` → U2 fails; restore pure `!exists` → A1 fails.
- `mock_builder.dart` guard: drop the `!exists` disjunct → A4 fails
  (absent interface no longer emitted).
- `zuraffa_barrel_exports.dart`: union the zuraffa surface
  UNCONDITIONALLY (ignore the bare-re-export check) → A5(a)/(c) fail.
- `zuraffa_barrel_exports.dart`: make `filterMock` return the input
  unfiltered → A5(a)/A6 fail; return empty always → A5(b) fails.
- Emission site: revert `mock_datasource_builder.dart` to the zuraffa
  filter → A6 fails (name verified only toward zuraffa leaks into the
  mock.dart hide when the surfaces diverge).
