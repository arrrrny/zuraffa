## Summary

The `dart_core` CI job (the pure-Dart gate: `dart test test --exclude-tags "flutter || e2e"`) has been **cancelled at its 30-minute ceiling on every recent run** — 12 of the last 15 ci.yaml runs, including both current master heads. Measured on run 34951330675: 6,962 tests across 1,037 suites completed in 29.5 min and the runner was killed mid-suite, with **57 more fast-lane suites never reached**. Root cause: ~116 heavyweight suites (run drivers, grammar sweeps, skin VmTap drivers, analyzer/compile self-hosting gates) were never tagged, so the lane absorbed exactly the workload `dart_test.yaml`'s own policy assigns to the `slow`/`e2e` tiers.

This PR re-homes them and keeps the lane honest:

- **124 tier-honest tag edits** — 72 suites gain `e2e` (the #1510 semantics: process-spawning/temp-project suites stay honest under direct `dart test <file>`, off the CI fast lane, still selected by `--preset=all`); 52 gain `slow` (in-process analyzer/compile gates, CI-proven ≥4s files, and 17+ regression-tier files that were leaking with tier-only tags).
- **Scoped parallelism** — the dart_core step runs `--concurrency=4`: the global `concurrency: 1` is a RAM/disk guard for the heavy temp-project lanes, not a unit-lane requirement. Serial residual after tagging: 736s (from 1,759s+ measured); at `-j4` the full residual lane finished in **5:07** locally on a 2019 Intel Mac *with* concurrent IDE test churn — under the 8-minute budget.
- **Structural pins so the drift cannot recur** (in `test/tier_integrity_test.dart`, next to the #1382/#1510 pins):
  - **B5** — the fast-lane budget census: every fast-lane-eligible suite matching a heavyweight criterion (spawns external processes, or an analyzer/compile self-hosting gate) must carry `e2e` or `slow`; failures enumerate the offenders.
  - **B6** — every regression-tagged file is kept off the CI lane by `slow` or `e2e` (tier-only tags leak into every default `dart test`).
  - **B7** — the dart_core step keeps its `--concurrency=4` and the B4-pinned `--exclude-tags` selector.

## Pre-existing master RED, repaired here (blocking any green lane)

- `bug_1388_gen_traces_fingerprint_test.dart` — born-red via a `stash` commit, red on every recent CI run. Test-side repair: guard-only pre-drift seed, faithful `UnimplementedError` stub (the progressed-artifact guard), a declared Layer Contracts surface so the drifted traces cell resolves, and the registered namespaced path read. B2 re-specced as an honest idempotent two-gen reuse. 2/2 green. Details: `.specify/bugs/dart-core-lane-timeout-overflow/tdd/fix-notes-1388.md`.
- `pubignore_export_guard_test.dart` — the guard flagged directive-shaped lines **inside `_render(r'''…''')` template barrels** the #1621 scaffold emits into *generated* projects. Repair: strip triple-quoted regions before scanning (generalizes the existing `${name}`/`@@` carve-outs). 3/3 green.

## Verification

- `dart test test/tier_integrity_test.dart` → **8/8** (B1–B4 pre-existing pins stay green).
- Deliberate-mutant sampling: three mutants (tier-only tag, stripped exclusion tag, dropped `--concurrency=4`) — **all killed**; the third exposed the FR-004 gap that B7 now closes.
- `dart analyze lib test --no-fatal-warnings` → 0 errors / 0 warnings; `dart format --set-exit-if-changed lib test` → clean.
- Full residual lane at the new CI shape: **5:06.71 wall, 5,940 passed** (local, contended machine; failures sampled serially pass — load flakes, details in the bug records).
- **This PR's own dart_core job is the dedicated-hardware confirmation** of the green + sub-8-minute budget.

Closes #1632.

Assessment: `.specify/bugs/dart-core-lane-timeout-overflow/assessment.md` · Fix: `fix.md` · TDD audit: `tdd/verification.md` (**PASS**)
