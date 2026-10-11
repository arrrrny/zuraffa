**Template Version**: `zuraffa-1.0`

# Spec: 1378-proof-prune

GitHub issue: arrrrny/zuraffa#1378 (verify-misfire / missing-integration,
EPIC #1136 Phase C / #1009 sub-issue 5 — proof receipt chain)

## Summary

Route-shell / mcp-scaffold receipts record TEMP SANDBOX artifact paths
(`../../../../tmp/issue_359_shell_ASCBZU/...`). After the sandbox is
garbage-collected, `zfa proof check` reports permanent
`deleted/missing artifact` findings (20 of 44 in the epic verify run) and
NO verb can cancel them — a killed background run or any sandbox GC
leaves the receipt chain permanently red.

## Locked decisions

1. `zfa proof prune` — a new subcommand on the proof family:
   - classifies every receipt by its artifact files: DEAD (every file
     missing), PARTIAL (some missing), ALIVE (all present);
   - dry run by DEFAULT: lists the dead receipts; `--apply` deletes them;
   - partial receipts are NEVER pruned (they may be hand-repairable, and
     blanket-deleting would hide real drift);
   - empty-receipt records count as alive (nothing to key on).
2. Exit codes: 0 on a completed prune (including zero dead); the verb
   never fails on the drift it exists to clean.
3. No prevention changes in this cycle (route-shell/mcp-scaffold writing
   sandbox-relative paths — recorded as follow-up design work).

## Functional requirements

- **FR-1**: dry run lists dead receipts by file name and deletes
  nothing.
- **FR-2**: `--apply` deletes exactly the dead receipts; live receipts in
  the same store survive.
- **FR-3**: partial receipts are kept and reported (`partial`), even
  under `--apply`.
- **FR-4**: no receipts → the honest `no receipts` message (exit 0).

## Acceptance scenarios

1. A dead sandbox receipt → dry run lists it by name; the file survives.
2. Dead + live receipts + `--apply` → the dead file is deleted, the live
   one survives (B2).
3. A partial receipt + `--apply` → kept, reported as partial (B3).
4. An empty receipts directory → `no receipts` (B4).

## Success criteria

- **SC-001**: After sandbox GC, `zfa proof prune --apply` restores the
  proof chain to green.
- **SC-002**: The proof suites stay green.

## Assumptions

- Existence (not digests) defines deadness — the check verb owns digest
  drift; prune owns receipt lifecycle.
- Deletion is unlink-only: no archival tombstone in v1 (the receipts are
  regenerable by re-running the named command; the `repro` field stays in
  the dry-run listing).
