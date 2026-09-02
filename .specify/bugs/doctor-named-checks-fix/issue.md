# Issue #793 — 'zfa doctor --fix': named checks + auto-heal for deps, build artifacts, baseline cache, manifest conformance

> Source: https://github.com/arrrrny/zuraffa/issues/793

## Enhancement: `zfa doctor --fix` — auto-heal the failure modes the healthcheck actually hit

### Motivation
`zfa doctor` currently reports environment/tooling info, but every problem it could detect during our sweep needed a human to know the fix: baseline cache corrupt/missing (silently falls back to live suites — slow), missing dev-deps after clone (mocktail/coverage/mutation_test), build_runner partial outputs (`.g.dart`/`.zorphy.dart` missing — we hit exactly this in `zfa build`'s diagnostic), stale `.zfa.json` plugin registrations.

### Proposal
1. `zfa doctor` grows **checks**: deps present, build artifacts fresh, baseline cache readable + fresh (RunBaselineCache already fail-safe — expose WHY it returned null), manifest conformance (#776), pubspec zuraffa version pin vs current CLI.
2. `zfa doctor --fix` applies the mechanical ones: `dart pub get`/`add` for missing deps, schedule/rebuild artifacts, invalidate stale `run-baseline.json`, regenerate `.specify` profile via `tdd init` (idempotent).
3. Output: per-check ✓/✗/fixed line + exit code (non-zero if any check remains failed) — CI-able.
4. `--format json` per #778.

### Acceptance criteria
- [ ] A sandbox with a corrupted run-baseline.json + missing mocktail dep reports both, `--fix` heals both, tests run green after.
- [ ] The `zfa build` partial-output scenario from the healthcheck is detected by a named check with a suggested fix command.
