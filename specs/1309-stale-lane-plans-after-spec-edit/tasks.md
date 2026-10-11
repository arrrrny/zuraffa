# Tasks 1309 — refresh stale lane plans on re-plan; add split --force
      (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are implemented after the
green loop (speckit.implement).

## Phase 0 — receipts + force surface (RED)

- [x] T0.1 Write `test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart`
      with the fixture feature (`specs/<tmp>/1309-fixture`, zuraffa-1.0
      spec, no `## Lanes`): seed legacy plan → `zfa tdd split` → assert
      receipt carries `spec_hash` (sha256 of spec.md) + `spec_mtime`.
      [FR-001, AC-3]
- [x] T0.2 Same file: `zfa tdd split` on a receipt-bearing feature
      refuses with exit 1 and the remedy message naming both
      `zfa tdd split --force` and `zfa tdd plan`. [FR-006, AC-4]
- [x] T0.3 Same file: `zfa tdd split --force` re-splits the
      receipt-bearing feature — exit 0, lane plans + meta-index +
      receipt overwritten, fresh `split_at`. [FR-005, AC-3]

## Phase 1 — plan staleness + regeneration (RED)

- [x] T1.1 Same file: `zfa tdd plan` on the receipt-bearing no-Lanes
      feature regenerates `04-ENGINE.md`/`04-SKIN.md`/`04-CONTRACT.md`
      + the meta-index from the current behavior set; stdout reports
      the stale split; the receipt gains `refreshed_at`/`refreshed_by`/
      `refreshed_rows`. [FR-002, FR-003, AC-1]
- [x] T1.2 Delete an FR from the spec after the split: the ghost row
      disappears from every lane plan file; `TestListReader` resolves
      the current set only. [FR-002, FR-004, AC-2]
- [x] T1.3 Unchanged spec + receipt: plan stays silent about
      staleness, lane plans still regenerate (meta-index preserved).
      [FR-004, AC-5]
- [x] T1.4 Lane plan mtimes ≥ spec mtime after plan and after split.
      [FR-004, AC-1]
- [x] T1.5 Legacy receipt (no `spec_hash`) + newer spec mtime → stale
      detection fires via the mtime fallback. [FR-003, AC-7]
- [x] T1.6 Never-split feature: plan writes the legacy single-file
      list, no lane files. [FR-007, AC-6]
- [x] T1.7 Record RED evidence: the suite fails against the unmodified
      tree (missing `--force` flag → usage refusal; no staleness
      detection → assertion failures); capture into
      tdd/verification.md.

## Phase 2 — GREEN implementation

- [x] T2.1 `split_command.dart`: add `--force`; bypass the receipt and
      meta-index guards under it; re-voice the one-shot refusal to name
      `--force`/plan; record `spec_hash` + `spec_mtime` in the receipt.
      [FR-001, FR-005, FR-006]
- [x] T2.2 `plan_command.dart`: receipt read + staleness check (hash
      primary, `split_at` mtime fallback for legacy receipts); heuristic
      lane synthesis (`_heuristicLaneResolution`) mirroring
      `SplitCommand._heuristic`; synthetic CORE/SKIN meta-index
      declarations; stale report line; receipt refresh after the lane
      write. [FR-002, FR-003, FR-004]
- [x] T2.3 Run the full 1309 suite GREEN; re-run the guarded
      neighbors (`split_command_1000_test.dart`,
      `plan_lanes_1000_test.dart`, `plan_command_ffi_835_test.dart`,
      `plan_skin_contract_1004_test.dart`, `bug_1261_*`) to prove the
      backward-compat contract. [FR-007]

## Phase 3 — non-behavioral (speckit.implement)

- [x] T3.1 Commit the spec-kit artifacts (spec.md, plan.md, tasks.md,
      tdd/test-list.md, tdd/traceability.md, tdd/verification.md).
- [x] T3.2 `dart analyze` the touched files; `dart format .`; confirm
      zero formatting diffs.
- [x] T3.3 Conventional Commit `feat(1309): ...` + push + PR closing
      #1309 with the staleness demo.
