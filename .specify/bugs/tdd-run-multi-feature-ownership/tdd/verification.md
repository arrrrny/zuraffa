# Verification — tdd-run-multi-feature-ownership (bug #801)

- **Date**: 2026-09-03
- **Branch**: `fix/801-tdd-run-multi-feature-ownership` (base: origin/master bd535c07)
- **Verdict**: PASS_WITH_GAPS

## Claim under verification

`zfa tdd run` supports multiple features in the same project: the issue's
exact two-feature journey runs without the reported `OwnershipConflict` at
gen, artifacts are namespaced per feature, and a run-level regression pin
guards the behavior.

## Evidence (all from real runs — see cycle-log.md)

| Check | Result |
|-------|--------|
| RED on 447ac1ac^ (pre-#827): issue signature verbatim (`A1 gen -> error`, OwnershipConflict, `stopped_at=A1:gen`) | reproduced, exit 1 |
| GREEN on this branch: full journey passes (run 1 complete; run 2 `[run] A1 gen -> ok`; no ownership conflict; no gen stop; namespaced coexistence + registries) | exit 0, 6:45 |
| Mutant M1 (flat paths restored in gen): pin catches the regression with the issue's signature | caught, exit 1; mutant restored |
| Probe: branch + PR #888's fix → run 2 `result=complete` exit 0 | journey fully green end-to-end |

## Honesty notes

- The first mutant attempt was a silent no-op (script escaping bug); it was
  detected, re-applied properly, and excluded from the evidence. Counted
  mutants: 1 applied, 1 caught.
- This PR ships NO production code change. The mechanism was fixed by
  #827/PR #869 (merged 2026-09-02, after the issue was filed; the reporter
  tested v6.1.0). This PR's deliverables are the run-level regression pin
  (the issue's repro surface was previously only pinned at bare `tdd gen`
  level) and this closure record.
- Known gap, deliberately NOT fixed here (one bug, one PR): without PR
  #888, feature-2's run stops at its first make (`generation-error`,
  `stopped_at=A1:make`) — bug #877's func-spawn ambiguity, which PR #888
  fixes. The test pins that a stop is never at gen, so it holds both
  before and after #888 merges. Verified by the cherry-pick probe above.
- The RED reproduction ran on linux_x64 with Dart 3.13.3; the issue was
  reported on macOS (Flutter 3.41). The failure mechanism is platform
  independent (pure file-layout logic); no macOS-specific behavior was
  exercised.
- Tier: slow+integration (real pub get + real `dart test` spawns inside
  temp fixtures). The default fast tier excludes it; CI's
  integration preset runs it.
