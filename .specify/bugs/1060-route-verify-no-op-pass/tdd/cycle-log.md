# TDD Cycle Log — 1060-route-verify-no-op-pass

- **Engine**: LLM-guided fallback (bug dir not under `specs/`)
- **Toolchain**: Dart 3.13.2 (stable), branch `fix/1060-route-verify-no-op-pass`,
  base 77e69f24

## Baseline — RED evidence (the bug, reproduced against the base commit)

Temp fixtures + `dart run bin/zfa.dart route verify --plain`, exit codes as
observed:

```
CASE A: no route inputs at all
  routes: 0
  drift: 0
  exitCode=0                                  ← lie-certifying PASS

CASE B: only CLI side present (product_routes.dart, 2 GoRoutes)
  routes: 2
  drift: 0
  exitCode=0                                  ← lie-certifying PASS

CASE C: both sides, matching paths (overlap)
  routes: 4
  drift: 2
  DRIFT /products …
  exitCode=0 (no --strict)                    ← drift exits 0

CASE D: both sides + /orders declared only on CLI side
  routes: 5
  drift: 2
  exitCode=0                                  ← /orders never reported
```

## Cycle 1 — V1…V7 (verdict set, exit codes, one-sided class, shell walker)

- 2026-09-05 — RED: `dart test test/plugins/route/route_verify_verdict_test.dart`
  → 10/10 failed. No `verdict` field (null), no honest exit codes, no
  `oneSided` findings, no `missingInput`, no `--strict` escalation, V5 help
  contract unmet.
- 2026-09-05 — Implementation landed:
  - `lib/src/commands/route_verify_command.dart` — `RouteVerifyVerdict`
    (match | drift | insufficient-input) with per-verdict exit codes
    (0 / 1 / 2; insufficient-input → 1 under `--strict`); pure `_assess`
    (missing-side → insufficient-input naming the missing system(s);
    path-set agreement → match; disagreement → drift); `_oneSidedFindings`
    (pure, canonical order); `*_shell.dart` added to CLI-side discovery;
    text output carries `verdict:` (and `missing-input:`) lines; `--json`
    payload carries `verdict`, `oneSided`, `missingInput`; help text
    documents verdicts and exit codes.
  - `test/plugins/route/route_verify_verdict_test.dart` (new, V1–V7).
  - `test/plugins/route/scenarios/sc_001_route_verify_test.dart` — updated:
    empty project now pins insufficient-input (exit 2). The old
    "exits 0 with no drift" expectation WAS the no-op PASS this bug removes.
  - `RouteDriftDetector` — untouched (zero diff).
- 2026-09-05 — GREEN:
  `dart test test/plugins/route/route_verify_verdict_test.dart
  test/plugins/route/scenarios/sc_001_route_verify_test.dart
  test/plugins/route/scenarios/sc_002_route_verify_discovery_test.dart`
  → 12/12 pass.

## Cycle 2 — scoped suite

- 2026-09-05 — `dart test test/plugins/route/ test/cli/route_command_test.dart`
  → 69/69 pass (detector U2, route table, scenarios sc_001/sc_002,
  bug_912 guard, deep-link/shell capabilities, U4 CLI surface, V1–V7).

## Mutation spot-checks (fallback audit; see verification.md)

- M1: insufficient-input exit `strict ? 1 : 2` → `2` (kill `--strict`
  escalation) → V4 fails. Killed.
- M2: path-set agreement check removed (always drift) → V1, V6, V7 fail.
  Killed.
- M3: `_oneSidedFindings` → `const []` → V2, V2b, V6 fail. Killed.
