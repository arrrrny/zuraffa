# Bug Assessment: 1060-route-verify-no-op-pass

- **Slug**: 1060-route-verify-no-op-pass
- **Created**: 2026-09-05
- **Source**: GitHub issue #1060 (severity critical, epic #1011 TRUTH-FLOOR)
- **Verdict**: valid
- **Severity**: critical

## Symptom

`zfa route verify` certifies PASS on projects it never actually verified:

1. No route inputs at all → `routes: 0, drift: 0`, exit 0.
2. One route system entirely missing → `routes: N, drift: 0`, exit 0.
3. Drift present, `--strict` omitted → exit 0.
4. A path declared by one system only (both systems populated) → not
   reported at all; the run stays a "no drift" PASS.
5. `*_shell.dart` branch routes (emitted by `zfa route shell`) are not
   discovered by the CLI-side walker.

Every one of these is indistinguishable from a true "both systems present,
path sets agree" PASS. That is the lie the TRUTH-FLOOR invariant forbids.

## Root cause

- The pure detector (`RouteDriftDetector`) and the file walkers landed with
  spec 0971 (commit 31e7b012, following PR #1025). The issue's "walkers
  never landed" is stale for file discovery, but the substance holds: the
  **verdict layer** never landed. The command prints counts and exits 0
  regardless of whether the inputs could be reconciled at all.
- No verdict taxonomy exists (`match | drift | insufficient-input`), no
  per-verdict exit codes, no missing-input naming, no one-sided drift
  class, and `--strict` only escalates overlap drift.

## Reproduction (captured in tdd/cycle-log.md, Baseline)

Temp project fixtures + `dart run bin/zfa.dart route verify --plain`:

- CASE A (no inputs): `routes: 0 / drift: 0`, exit 0 — LIE.
- CASE B (only `product_routes.dart`): `routes: 2 / drift: 0`, exit 0 — LIE.
- CASE C (both sides matching paths): drift found, exit 0 without
  `--strict` — LIE.
- CASE D (both sides + `/orders` only on CLI side): `/orders` never
  reported, exit 0 — LIE.

## Proposed remediation (implemented on this branch)

- Verdict layer in `RouteVerifyCommand` (pure `_assess`):
  `match | drift | insufficient-input`.
- Exit codes: match=0, drift=1, insufficient-input=2 (1 with `--strict`).
- One-sided paths become drift-class findings, named with their declaring
  entries, in both text and `--json` (`oneSided` array).
- `missingInput` names the exact missing system(s) in text and JSON.
- CLI-side walker extended to `*_shell.dart` registrations.
- `RouteDriftDetector` left byte-identical (pure API untouched).

## Out of scope

- Comparing route `name:` fields between systems (orders specify path-level
  comparison).
- Migration/deprecation of either route system (spec 0971 Phase 2/3).
