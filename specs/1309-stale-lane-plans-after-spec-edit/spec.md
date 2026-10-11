**Template Version**: `zuraffa-1.0`

# Spec: 1309-stale-lane-plans-after-spec-edit

## Acceptance Scenarios

1. **Given** a feature whose `tdd/split-receipt.json` exists and whose `spec.md` gained a new functional requirement after the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** plan reports the stale split, regenerates `tdd/04-ENGINE.md` and `tdd/04-SKIN.md` from the current behavior set, and the regenerated engine plan carries the new requirement's behavior row.
   **Type**: acceptance
2. **Given** a split feature whose `spec.md` had a functional requirement deleted after the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** the deleted requirement's ghost row no longer appears in any lane plan file and the shared reader resolves the current behavior set only.
   **Type**: acceptance
3. **Given** a feature whose split receipt exists **When** the user runs `zfa tdd split` with `--force` **Then** the split re-runs, overwriting the lane plans, the meta-index, and the receipt with a fresh receipt recording the current spec state.
   **Type**: acceptance
4. **Given** an already-split feature **When** the user runs `zfa tdd split` without the force flag **Then** the refusal names the actual remedy: `zfa tdd split --force` to re-split, or `zfa tdd plan` to refresh the lane plans from the current spec.
   **Type**: acceptance
5. **Given** a receipt-bearing feature whose spec is unchanged since the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** no staleness is reported and the lane plans still reflect the current behavior set after the run.
   **Type**: acceptance
6. **Given** a never-split feature with no split receipt **When** the user runs `zfa tdd plan` on the feature **Then** the legacy single-file plan is written exactly as before and no lane plan files appear.
   **Type**: acceptance
7. **Given** a split receipt written before the spec-hash fields existed **When** the user runs `zfa tdd plan` and the spec mtime is newer than the receipt's split timestamp **Then** the staleness is still detected through the mtime comparison and the lane plans are regenerated.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: The split receipt records the sha256 digest of the spec content (`spec_hash`) and the spec file's modification time (`spec_mtime`) captured at split time, so a later plan run can compare the current spec against the state the split derived from.
- **FR-002**: When a split receipt exists and the spec declares no lanes section, `zfa tdd plan` regenerates the lane plans (`tdd/04-ENGINE.md`, `tdd/04-SKIN.md`, `tdd/04-CONTRACT.md`) and the lane meta-index from the current behavior set using the same kind heuristic the split command applies, so deleted behaviors disappear and added behaviors appear in the regenerated files.
- **FR-003**: When the spec changed since the receipt was written (the recorded `spec_hash` differs from the current spec digest, or the receipt carries no hash and the spec mtime is newer than the receipt's split timestamp), plan reports the stale split before writing, and after writing it refreshes the receipt's spec digest fields plus `refreshed_at`, `refreshed_by` and `refreshed_rows` audit entries so the detection fires only on the next real spec change.
- **FR-004**: After `zfa tdd plan` or `zfa tdd split` completes on a receipt-bearing feature, every lane plan file reflects the current behavior set in the spec and no stale requirement rows remain. The lane plan modification times are at least the spec's modification time when marker emission is disabled; when marker emission is enabled, `persistMarkerEmission()` runs after `PlanCommand` writes the lane plans and may make `spec.md` newer, so rerun `zfa tdd plan --no-emit-markers` to require and test the mtime guarantee.
- **FR-005**: The split command accepts a force flag that re-splits a receipt-bearing feature: the behavior rows re-read through the shared reader, the lane plans and meta-index overwritten, and a fresh receipt written recording the current spec digest and mtime.
- **FR-006**: The one-shot refusal names the actual remedy — use the force flag to re-split, or run plan to refresh the lane plans from the current spec — instead of deadlocking with the plan command's lane guidance.
- **FR-007**: Features never split plan exactly as before; features whose specs declare the lanes section plan through the existing lane path unchanged; the staleness detection fires only when a split receipt exists AND the spec changed since the receipt was written.
