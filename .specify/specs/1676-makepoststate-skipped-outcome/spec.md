# 1676-makepoststate-skipped-outcome

- **Spec ID**: 1676-makepoststate-skipped-outcome
- **Created**: 2026-09-17
- **Source**: GitHub issue #1676 (SPEC 1676 — MakePostState fast path never
  engages on the post-#1651 hand-step flow)
- **Type**: perf (P1 — High: every hand-implemented behavior re-pays the
  full refactor pipeline)
- **Branch**: fix/1676-makepoststate-skipped-outcome

## Problem

The #1652 `MakePostState` fast path only records on make's **`green`**
outcome and deliberately writes nothing on the **`skipped`** outcome
(`run_driver_core.dart`, the `recordMakePostState` block: "The #741
already-green skip (`skipped`) certifies no new tree state and deliberately
writes nothing"). But the post-#1651 hand-step flow — the recovery the
#1651 vacuous-green refusal itself prescribes — ends every behavior at
exactly that `skipped` outcome: the agent hand-implements the subject, make
finds the target test already passing, and skips generation. Result: the
two fixes don't compose. Every hand-implemented behavior pays the **full
refactor pipeline** (preflight suite + build/format/fix + re-proof) over a
tree make just certified seconds earlier.

**Measured** (zcalc2 probe, full suite ≈ 12 s), all behaviors
hand-implemented per #1651, every make `skipped`, every refactor ran the
full path:

| behavior | refactor span |
|---|---|
| A1 | 19.1s |
| A2 | 32.6s |
| U1 | 27.0s |
| U2 | 15.4s |
| U3 | 23.9s |
| U4 | 18.4s |

≈ **136 s of full-path refactor** per feature where the tree was
byte-identical to what make certified ~seconds earlier (`applied: 0
actions`, `no-op: true`). For comparison, the one refactor following a real
`green`-outcome make inherited in **~1 s** (`make-post-state hit (issue
#1652)`).

**Why the skip transition's reasoning doesn't hold**: The code comment
assumes "skipped" means "no certification happened". In the #1651
hand-step flow that assumption is false: the agent edited `test/` and
`lib/` between runs, and make's skip transition **ran the target test on
that new tree and certified it green** ("subject drift accepted (issue
#1162) … the skip transition re-binds the green evidence to the current
subject shape"; spec 1423 refreshes the hand-delta receipts from the
current bytes). That is live post-state evidence on the current tree —
precisely what `MakePostState` exists to record — but the record is never
written.

## Goal

The driving run writes `MakePostState` on make's `skipped` outcome too
(gated on make having run and passed the target test, which the skip
transition already does), so the next refactor's fast path inherits the
pipeline instead of re-running it over a tree make just certified.

## Success criteria (measurable)

- **SC-1**: When a make step completes with outcome `skipped` (the #694
  skip transition — it ran and passed the target test on the current tree)
  in a run that records make post-state, the record
  `tdd/make-post-state.json` is written: `behavior_id` names the skipping
  behavior, `lib_digest`/`test_digest` match the on-disk trees, and
  `green_verdict` honestly names the evidence (`outcome=skipped`, the
  skip-transition target-test certification — never mislabeled as a
  `green`-outcome record).
- **SC-2**: The exit-disagreeing skip token (outcome `skipped`, non-zero
  exit — the bug #986 terminal classification, the #657/#694-era drift
  contract) records under the same gate: the token certifies the target
  test passed; the token is the gate, not the exit code.
- **SC-3**: The next `--pass-batch` refactor spawn on the skip-certified
  tree inherits the pipeline (`make-post-state hit (issue #1652)`; zero
  suite spawns) — the fast path engages after a hand-step flow.
- **SC-4**: The full-suite gate is preserved exactly where designed: the
  inheritance keeps naming that the full suite did NOT run at this tree
  and still runs at the phase-2b batch pass, feature completion, and
  nightly (spec 069 T001); the refactor-proved pass-batch ledger keeps
  precedence; every existing mismatch dimension (tree drift, baseline
  rewrite, config rewrite, exempt-set difference, corrupt record, missing
  `--pass-batch`, `--full-reproof`) still runs the full pipeline.
  **Certification scope, stated explicitly (deliberate trade-off)**: a
  skip-transition certification covers the TARGET TEST only — the skip
  transition runs no suite baseline and no suite guard (both are behind
  `if (!alreadyGreen)` in `make_command.dart`, "the skip transition runs
  no guard — nothing was generated") — so a skip-written inheritance
  deliberately defers **all** cross-behavior suite regression detection
  (e.g. a hand-edit that satisfies behavior N's target test but breaks an
  already-DONE behavior M) to the feature-completion verify preflight and
  the nightly run. The verdict string names that scope honestly
  (`target-test green evidence`); widening the evidence to the suite is a
  consumer-side change and is out of this spec's scope by design (the
  chosen shape is write-side only).
- **SC-5**: `green`-outcome behavior is unchanged: same recording
  condition path, and the `green` verdict string stays byte-identical
  (`make <id> outcome=green exit <n> (post-generation green evidence)`).
  No other terminal make token (`adopted`, `adopted-placeholder`,
  `adopted-interrupted`, `green-with-failed-build`, `born-green`) changes
  its recording behavior in this spec.

## Hard constraints

- Fix ONLY the `MakePostState` recording condition (the
  `recordMakePostState` block in `run_driver_core.dart` plus the honest
  verdict wording in `_recordMakePostState`); do NOT remove or alter the
  full-suite gate at phase-2b / feature completion / nightly.
- One PR per spec.
- The fix must: (1) write `MakePostState` on `skipped` when the skip
  transition ran and passed the target test, (2) engage the fast path on
  the next refactor (inherit instead of full re-run), (3) preserve
  full-suite gates where designed, (4) not change `green`-outcome
  behavior.
- A record write failure stays a warning, never a run failure (#1652
  U5c contract): a missing record costs the next refactor one full
  pipeline, never correctness.

## Remediation (from the issue)

Write `MakePostState` on the `skipped` outcome too (gated on make having
run and passed the target test, which the skip transition already does),
or have the refactor's fast path also accept the skip transition's fresh
target-test evidence. The chosen shape is the write-side gate: it keeps
the refactor-side consumer untouched (it is already verdict-agnostic) and
the record stays the single derived-data artifact both flows read. The
full suite gate is preserved at phase-2b / feature completion / nightly
per the existing #1652 design notes.
