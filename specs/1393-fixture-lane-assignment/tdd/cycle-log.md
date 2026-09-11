# Cycle Log — Spec 1393

## Cycle 1 — RED (pre-fix pins + issue reproduction)

- behavior: B1/B2/B4 (pin suite)
- outcome: red — `+1 -3`
- command: `dart test test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart`
- evidence:
  - B1 red: the CORE lane declares `behaviors: [A1, A2, U1]` — U1 is CORE.
  - B2 red: no FR-002 — the fixture declares zero engine-side unit behaviors
    with contract traces.
  - B4 red: the committed split receipt classifies `U1: CORE` and carries no
    U2 row.
  - B3 green: `parseAdaptiveSkinContract` accepts the committed Skin Contract
    (the malformed `adaptive_slots: obile, ...` named in #1393 was already
    repaired on master; spec 1377 recorded the repair).
- at: 2026-09-10T22:0xZ

## Cycle 2 — RED (the issue's engine stop, reproduced verbatim)

- behavior: U1 / A1 / A2 (engine lane, shipped fixture)
- outcome: stopped — `stopped_at=U1:make`
- command: `zfa tdd run 004-login-ui --project <example>`
- evidence:
  - `[run] A1 make -> unexpressible` → deferred (phase 2)
  - `[run] A2 make -> unexpressible` → deferred (phase 2)
  - `zfa tdd gen: WARNING [zfa:tdd: guard-only] behavior "U1" ...`
  - `[run] U1 make -> vacuous-green` → the run stops (`issue #1259/#1308`
    guards firing as designed on a mislaned presentation behavior)
- at: 2026-09-10T22:3xZ

## Cycle 3 — GREEN (re-split + regenerated evidence + driven cycle)

- behavior: B1–B5
- outcome: green
- evidence:
  - Fix applied: Lanes `CORE [A1, A2, U2]` / `SKIN [W1, U1, A3–A7]`; FR-002
    added with `traces: LoginValidation.isSubmittable`; the **Function** row
    `LoginValidation: isSubmittable(String email, String password) -> bool`
    declared under Layer Contracts.
  - `zfa tdd plan 004-login-ui --project example` →
    `route: U2 -> unit lane (func surface) [declared: contract row:
    LoginValidation]`.
  - `zfa tdd split 004-login-ui --force --project example` → receipt
    classification: A1/A2/U2 CORE; W1/U1/A3–A7 SKIN.
  - Engine cycle (unattended — every implementation step CLI-generated):
    U2 gen → verify-red certified → make `func` scaffold green;
    A1/A2 make `unexpressible` → deferred → phase 2 composition
    (`composition fallback: 1 green unit subject(s) (U2)` →
    `zfa tdd compose` + build) → `target test exit: 0` → green;
    refactor pass `refactored applied=1` per behavior (baseline-tolerant
    re-proof, issue #922 — the tolerated failure is the skin lane's U1
    guard pair, the designed hand-delta seam).
  - Pin suite: `+4 All tests passed!`
- at: 2026-09-11T00:1xZ

## Cycle 4 — Receipt

- `example/specs/004-login-ui/tdd/04-engine-receipt.json`:
  `verdict: green`, `result: complete`, `stopped_at: null`,
  `counts: {total: 3, pending: 0, red: 0, green: 0, done: 3}`.
- Skin lane (out of scope, recorded honestly): the meta run stops at
  `U1:make` — the vacuous-green hand-delta seam for the view behavior
  (issues #1259/#1308; spec 1377 locked decision 4).
