# Tasks: zero-route-gorouter-launch

Test tasks (mandatory, non-skippable) drive the fix; implementation tasks follow each behavior's green test.

## Tests (TDD loop — driven by `zfa tdd run`)

- [x] [behavior: A1] Test: emitted GoRouter installs `errorBuilder` + runtime empty-table fallback (widget lane refused: issue #938 pure-Dart repo — hand-proven, emission-level) — traces AC-1
- [x] [behavior: A2] Test: initial `/` resolution renders the placeholder instead of throwing (widget lane refused: issue #938 — hand-proven, emission-level) — traces AC-2
- [x] [behavior: A3] Test: skin-audit variant carries the same `errorBuilder` / fallback alongside the observer (engine: verify-red certified → born-green) — traces AC-3
- [x] [behavior: A4] Test: runtime empty-check leaves a real route table untouched (engine: verify-red certified → born-green) — traces AC-4
- [x] [behavior: A5] Test: placeholder survives `routing/index.dart` regeneration (engine: verify-red certified → born-green) — traces AC-5
- [x] [behavior: A6] Test: pure-Dart smoke test stays router-free (engine: verify-red certified → born-green) — traces AC-6
- [x] [behavior: A7] Test: Flutter day-zero smoke test pumps the app shell and asserts `/` resolves (widget lane refused: issue #938 — hand-proven at template level; live pump runs in the generated app) — traces AC-7
- [x] [behavior: A8] Test: golden tests assert the new `errorBuilder` / fallback output (engine: verify-red certified → born-green) — traces AC-8

## Implementation (non-behavior work — driven by `zfa tdd run` / implement)

- [x] [behavior: A1..A8] Remediate `AppShellBuilder.buildAppRouter()` (bare + skin-audit) to emit `errorBuilder` + empty-table fallback route
- [x] [behavior: A7] Extend `SmokeTestWriter` Flutter flavor to pump the shell / resolve `/`
- [x] [behavior: A8] Golden ripple verified: app-shell builder/skin-audit, skew matrix, cli/writers suites green without edits (substring assertions remain valid)
- [x] [behavior: A1..A8] Gate proof over the final tree: dart format + dart analyze + chunked fast suite (loop driver's full-suite refactor gate infeasible on this machine — see fix.md Deviations)
