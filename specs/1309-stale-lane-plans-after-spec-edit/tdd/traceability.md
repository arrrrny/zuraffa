# Traceability: 1309-stale-lane-plans-after-spec-edit

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:4b971efb0e20bb8db331224b9c652f10cf0f7820cc2bfcbf94cefb4871c9006a
statements: 14
automated: 14
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 7 | 1. **Given** a feature whose `tdd/split-receipt.json` exists and whose `spec.md` gained a new functional requirement after the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** plan reports the stale split, regenerates `tdd/04-ENGINE.md` and `tdd/04-SKIN.md` from the current behavior set, and the regenerated engine plan carries the new requirement's behavior row. | A1 | automated |
| AC-2 | 9 | 2. **Given** a split feature whose `spec.md` had a functional requirement deleted after the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** the deleted requirement's ghost row no longer appears in any lane plan file and the shared reader resolves the current behavior set only. | A2 | automated |
| AC-3 | 11 | 3. **Given** a feature whose split receipt exists **When** the user runs `zfa tdd split` with `--force` **Then** the split re-runs, overwriting the lane plans, the meta-index, and the receipt with a fresh receipt recording the current spec state. | A3 | automated |
| AC-4 | 13 | 4. **Given** an already-split feature **When** the user runs `zfa tdd split` without the force flag **Then** the refusal names the actual remedy: `zfa tdd split --force` to re-split, or `zfa tdd plan` to refresh the lane plans from the current spec. | A4 | automated |
| AC-5 | 15 | 5. **Given** a receipt-bearing feature whose spec is unchanged since the receipt was written **When** the user runs `zfa tdd plan` on the feature **Then** no staleness is reported and the lane plans still reflect the current behavior set after the run. | A5 | automated |
| AC-6 | 17 | 6. **Given** a never-split feature with no split receipt **When** the user runs `zfa tdd plan` on the feature **Then** the legacy single-file plan is written exactly as before and no lane plan files appear. | A6 | automated |
| AC-7 | 19 | 7. **Given** a split receipt written before the spec-hash fields existed **When** the user runs `zfa tdd plan` and the spec mtime is newer than the receipt's split timestamp **Then** the staleness is still detected through the mtime comparison and the lane plans are regenerated. | A7 | automated |
| FR-001 | 24 | - **FR-001**: The split receipt records the sha256 digest of the spec content (`spec_hash`) and the spec file's modification time (`spec_mtime`) captured at split time, so a later plan run can compare the current spec against the state the split derived from. | U1 | automated |
| FR-002 | 25 | - **FR-002**: When a split receipt exists and the spec declares no lanes section, `zfa tdd plan` regenerates the lane plans (`tdd/04-ENGINE.md`, `tdd/04-SKIN.md`, `tdd/04-CONTRACT.md`) and the lane meta-index from the current behavior set using the same kind heuristic the split command applies, so deleted behaviors disappear and added behaviors appear in the regenerated files. | U2 | automated |
| FR-003 | 26 | - **FR-003**: When the spec changed since the receipt was written (the recorded `spec_hash` differs from the current spec digest, or the receipt carries no hash and the spec mtime is newer than the receipt's split timestamp), plan reports the stale split before writing, and after writing it refreshes the receipt's spec digest fields plus `refreshed_at`, `refreshed_by` and `refreshed_rows` audit entries so the detection fires only on the next real spec change. | U3 | automated |
| FR-004 | 27 | - **FR-004**: After `zfa tdd plan` or `zfa tdd split` completes on a receipt-bearing feature, every lane plan file reflects the current behavior set in the spec and no stale requirement rows remain. The lane plan modification times are at least the spec's modification time when marker emission is disabled; when marker emission is enabled, `persistMarkerEmission()` runs after `PlanCommand` writes the lane plans and may make `spec.md` newer, so rerun `zfa tdd plan --no-emit-markers` to require and test the mtime guarantee. | U4 | automated |
| FR-005 | 28 | - **FR-005**: The split command accepts a force flag that re-splits a receipt-bearing feature: the behavior rows re-read through the shared reader, the lane plans and meta-index overwritten, and a fresh receipt written recording the current spec digest and mtime. | U5 | automated |
| FR-006 | 29 | - **FR-006**: The one-shot refusal names the actual remedy — use the force flag to re-split, or run plan to refresh the lane plans from the current spec — instead of deadlocking with the plan command's lane guidance. | U6 | automated |
| FR-007 | 30 | - **FR-007**: Features never split plan exactly as before; features whose specs declare the lanes section plan through the existing lane path unchanged; the staleness detection fires only when a split receipt exists AND the spec changed since the receipt was written. | U7 | automated |

