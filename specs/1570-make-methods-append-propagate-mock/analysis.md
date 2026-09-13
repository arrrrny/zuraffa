**Template Version**: `zuraffa-1.0`

# Analysis: 1570-make-methods-append-propagate-mock

Date: 2026-09-14 · Artefacts: `spec.md` (zuraffa-1.0), `plan.md`, `tasks.md`

## Cross-artifact consistency

- **Covered**: A1→T001/T009, A2→T002/T008, A3→T003; U1→T004, U2→T005,
  U3→T006, U4→T007, U5→T008; SC-001..SC-005 all traced to at least one
  task; FR-001..FR-008 all traced. No orphan acceptance scenario, no
  dangling FR.
- **Grammar**: spec carries the `**Template Version**: zuraffa-1.0`
  marker; every acceptance scenario carries a `**Type**` marker
  (`acceptance` / `unit`); FR traces point to rows declared under
  `## Layer Contracts` / `## Key Entities` (`MockDataSourceBuilder`,
  `MockStalenessDetector`, `MockCertification`, `ParsedUseCaseInfo`,
  `GeneratedFile`) — no dangling traces.
- **Scope guard (FR-008 / hard constraints)**: tasks touch ONLY
  `lib/src/plugins/mock/` (builder + new service) and
  `test/plugins/mock/`. The interface writer
  (`lib/src/plugins/datasource/builders/interface_generator.dart`), the
  real datasource writers (`remote_generator.dart`,
  `local_generator*.dart`), the repository writers, and the
  analyze/build gates (`build_command.dart`) are NOT in any task.
  Consistent with the issue's "Fix the mock lane's skip/append logic
  only".
- **MVP ordering**: T001–T003 (P1) encode the reported break and the
  two contract axes of the fix (repair / fail-open); T004–T008 pin the
  shape semantics and precedence; T009 covers the real plugin entry;
  T010–T011 are the implementation the red tests demand; T012 is
  doc-only. Dependency order: tests (red) → detector → wiring → docs.
- **Idempotence risk (resolved)**: FR-005 keeps in-sync re-runs
  `skipped` — the fix cannot turn every `zfa make` re-run into a mock
  rewrite (would change receipts/cert digests on every run and break
  SC-003/`zfa proof check` idempotence expectations).
- **Certification coherence**: the detector reuses the certification's
  own extraction primitives (FR-003) — repair and cert gate cannot
  disagree about what "missing" means; post-repair runs re-certify with
  `missingMethods` empty (SC-002).
- **Dry-run honesty**: T008 pins that `GenerationTransaction`'s dry-run
  semantics (operations recorded, bytes untouched) carry the repair —
  no separate dry-run code path.

## Findings & resolutions

1. **Finding**: the spec's A1 wording ("the mock lane runs … or `zfa
   mock create`") could read as two lanes needing separate tasks.
   **Resolution**: both surfaces funnel through the same
   `MockDataSourceBuilder.generateMockDataSource` — T009 exercises the
   plugin entry; `mock create` inherits the fix through
   `CreateMockCapability._generateFiles` → `MockPlugin.generate` → the
   same builder. One lane, one fix.
2. **Finding**: invented-surface (extra mock members) handling was
   underspecified. **Resolution**: only MISSING members are repaired
   (compile-blocking); invented surface stays the certification gate's
   `inventedMethods` report — removing members would risk clobbering
   custom-usecase helpers (T006 pins this).
3. **Finding**: `--force` + drifted mock — full regeneration already
   heals; arming the shape repair under force would be dead code.
   **Resolution**: detector arms only on the exact skip condition
   (`!appendToExisting && !force && !revert`); T007 pins precedence.

**Verdict**: artifacts coherent — proceed to `/speckit.tdd.plan`.
