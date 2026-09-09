# Plan 1309 — refresh stale lane plans on re-plan; add split --force

## Technical Context

- Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0` respected);
  pure-Dart package — no Flutter SDK in the loop.
- Issue: post-split spec edits leave the lane plans (`tdd/04-ENGINE.md`
  etc.) stale and no command can refresh them. The two commands'
  guidance deadlocks:
  - `zfa tdd split` refuses: "already split" (one-shot guard,
    `split_command.dart` lines naming the receipt).
  - `zfa tdd plan` only writes lane files when the spec declares
    `## Lanes` (`plan_command.dart`:
    `lanes.isEmpty ? null : _resolveLanes(...)`), so a feature split
    from a spec with NO lanes section gets a re-plan that rewrites only
    `tdd/test-list.md` (even demoting the meta-index back to a
    single-file list) and leaves the lane plans untouched — ghost
    behaviors (deleted FRs) survive in `04-ENGINE.md`, new FRs never
    appear.

## Touched surfaces (hard constraint: these three only)

| Surface | Change |
|---|---|
| `lib/src/plugins/tdd/commands/plan_command.dart` | Staleness detection + lane plan regeneration: when `tdd/split-receipt.json` exists and the spec declares no `## Lanes`, plan synthesizes the split kind heuristic over the CURRENT behavior set (widget/theme → SKIN, rest CORE — the same rule `SplitCommand._heuristic` applies) and rides the existing lane-write block; a spec whose digest/mtime is newer than the receipt is reported as a stale split; the receipt is refreshed after the write. |
| `lib/src/plugins/tdd/commands/split_command.dart` | `--force` flag (re-split over an existing receipt: rows re-read via the shared reader, lane plans + meta-index + receipt overwritten); the one-shot refusal re-voiced to name the actual remedy; receipt format gains `spec_hash`/`spec_mtime`. |
| `tdd/split-receipt.json` format | New fields: `spec_hash` (sha256 of `spec.md` content at split time), `spec_mtime` (spec mtime at split time, omitted when the spec file is absent). Plan-side refresh adds `refreshed_at`/`refreshed_by`/`refreshed_rows`. Legacy receipts (no `spec_hash`) fall back to the mtime comparison against `split_at`. |

Untouched by contract: the core engine cycle, the test-list generation
(`_render`), the lane derivation algorithm (`_resolveLanes`,
`_heuristic`, the `render*Plan` emitters in `lane_split.dart`), the
coverage/template gates, `TestListReader`.

## Staleness decision table (issue #1309)

| receipt | spec lanes | spec vs receipt | plan behavior |
|---|---|---|---|
| absent | any | — | legacy single-file path, unchanged |
| present | declared | any | existing `## Lanes` lane path, unchanged (lane files always rewritten) |
| present | none | unchanged (hash equal; or mtime ≤ `split_at` for legacy receipts) | lane plans regenerated from the current behavior set, no staleness report |
| present | none | changed (hash differs; or mtime > `split_at` for legacy receipts) | stale split reported + lane plans regenerated + receipt refreshed |

## Implementation strategy

MVP-first, dependency-ordered (T1 → T4):

1. **T1 — receipt format (RED).** `split` records `spec_hash` +
   `spec_mtime`. Test: receipt contents after a split.
2. **T2 — split --force (RED).** Force re-splits over a receipt;
   refusal names `--force`/plan. Tests: force run overwrites; plain run
   refuses with the remedy.
3. **T3 — plan stale detection + regeneration (RED).** Plan on a
   receipt-bearing no-Lanes feature regenerates the lane plans from the
   current behavior set; a spec edit is reported as a stale split and
   refreshes the receipt; an unchanged spec stays silent; legacy
   receipts fall back to mtime. Tests: new FR appears, deleted FR's
   ghost row disappears, meta-index preserved, and mtimes ≥ spec when
   rerun with `--no-emit-markers` (marker emission persists `spec.md`
   after the lane writes and is the supported exception).
4. **T4 — docs/spec artifacts (non-behavioral).** This feature's
   committed artifacts + the verification record.

Backward-compat guardrails (FR-007): every existing behavior in
`plan_lanes_1000_test.dart`, `split_command_1000_test.dart`,
`plan_command_*_test.dart` must stay green — the legacy path fires only
when no receipt exists, the Lanes path is untouched, and the heuristic
synthesis reuses the exact classification rule split applies.
