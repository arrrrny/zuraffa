# TDD Cycle Log — Spec 1645-pipeline-running-binary-tier (append-only)

## Baseline (pre-loop)

- Feature: specs/1645-pipeline-running-binary-tier (issue #1645, follow-up
  to #1643).
- Suite state before any behavior work: fast tier green on `master`
  (2ac6b9d7); the defect lives in the pipeline resolver's tier ORDER, not
  in missing code — the fix is a reorder, so reds are assertion reds, not
  load errors.
- Test list: 10 behaviors — 2 acceptance (A1, A2, assertion-red pre-fix),
  5 unit rows driven in this loop (U1–U3 new; U4/U5 re-shapes of the
  existing bug-#864 tier pins), 5 covered-existing (U6–U10, pinned by the
  verification pass).
- Driving toolchain: Dart 3.13.3 stable on macOS arm64; tests run scoped
  (per-file / services dir), never the whole repo (tdd-profile; issue
  #1642 TMPDIR hazard).
