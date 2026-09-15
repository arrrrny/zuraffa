# TDD Cycle Log — Spec 1652-refactor-digest-gate (append-only)

## Baseline (pre-loop)

- Feature: specs/1652-refactor-digest-gate (issue #1652, perf).
- Suite state before any behavior work: fast tier green on `master`
  (06cbf85e); the defect is an ECONOMICS defect (redundant re-proofs),
  not missing code — the reds are evidence-shape reds (A1: the pipeline
  runs where it should inherit; U5: the record is never written), and
  every fallback row is green-by-design pre-fix.
- Test list: 8 behaviors — 2 acceptance (A1 red, A2 guard), 6 unit
  (U1–U4 command-level guards, U5 red, U6 guard). All driven in the two
  existing harness tiers; no real AOT compile anywhere.
- Driving toolchain: Dart 3.13.3 stable on macOS arm64; TMPDIR pinned to
  the clone-local `.tmpdir/` for every run (issue #1642 hazard).
