# TDD Cycle Log — Spec 1355

## RED (2026-09-09)
- `dart test test/simulation/worlds/simulate_worlds_command_test.dart --plain-name "issue #1355"`
- result: `+3 -2` — B1 (bare-name repro exits 1 RED, FixtureMismatch — the
  issue signature) and B5 (no bare-name wording in help) RED; B2/B3/B4
  guards green as declared in the red protocol.
- tests committed first: `test(1355): certified red ...`

## GREEN (2026-09-09)
- fix: legacy branch resolves a bare `--feature` name under `specs/` only
  when (a) `--fixtures` is absent, (b) the value contains no `/`, and
  (c) `specs/<name>` exists; help text documents the bare-name rule.
- result: `+42 All tests passed!` (worlds 30 + simulate command + skin).
- analyze clean, format clean.

## Live repro proof
Scratch workspace, CWD root: `simulate --scaffold specs/968-simulation-worlds
--family firebase-auth` → exit 0; then `simulate --feature
968-simulation-worlds` (bare) → `SIMULATE golden -> GREEN (1/1 plays,
guard=active)` exit 0 — the issue's repro is fixed without the path-form
workaround.
