# Bug Verification: widget-kind row with a func verb ("renders") routes to tdd func — generation-error; the #939 view lane never engages

- **Slug**: widget-func-verb-routing
- **Tested**: 2026-09-03
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md

## Summary

The bug no longer reproduces: a widget-kind behavior whose description says "renders" now plans as unexpressible naming the view lane, and `zfa tdd make` routes it through the #939 view-builder lane (`tdd view <id>` + build) to certified green — pre-fix this exact shape dead-ended in `outcome=generation-error`. All regression suites are green (879/879 tdd fast tier, #939 lane 4/4), and the TDD audit verdict is PASS with one in-audit pin strengthening.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test --preset=all test/plugins/tdd/make_command_widget_950_test.dart` (drives the real `zfa tdd make` CLI with the issue's exact scenario literal `the widget renders 'Hello, shopper'`, kind: widget row, gen-shaped view-builder stub) | pass | exit 0, `outcome=green`, `widget lane: view-builder generation`, dispatch `[tdd view A-100 …, build]`, no `tdd func` anywhere; pre-fix the same fixture produced the issue's verbatim failure (`plan: 2 step(s)` → `generation-error`, exit 1 — ./tdd/red-evidence.md) |
| New / updated tests (planner) | `dart test test/plugins/tdd/services/generation_planner_widget_950_test.dart` | pass | 8/8 — five guard pins + three regression pins (unit-kind, kindless, ffi precedence) |
| Regression suite | `dart test test/plugins/tdd` | pass | 879/879, two full runs at HEAD |
| Regression suite (neighboring lane) | `dart test --preset=all test/plugins/tdd/make_command_widget_939_test.dart` | pass | 4/4 — the #939 view-lane contract is unchanged |
| Lint / type-check | `dart analyze lib/src/plugins/tdd/services/generation_planner.dart test/plugins/tdd/{services/...,make_command_widget_950_test.dart}` | pass | No issues found |
| Mutation sampling | guard disabled → `+3 -5` caught; wrong-route-command reason → `+7 -1` caught (after pin 3 strengthened); phrasing mutant survived (judged non-load-bearing) | pass | ./tdd/verification.md Mutation results |

## Output Excerpts

Pre-fix (RED, the issue verbatim):
```
   plan: 2 step(s)
   target test exit: 1
zfa tdd make: target test still fails after generation (exit 1).
make: behavior=A-100 outcome=generation-error feature=090-tdd-fixture
```

Post-fix (GREEN):
```
00:17 +1: All tests passed!          # W-A1 slow pin
00:00 +8: All tests passed!          # planner pins
02:03 +879: All tests passed!        # tdd plugin fast tier
```

## Residual Risks

- The reporter's home project (`~/zik_zak_test`) was not available; the reproduction was exercised at the real CLI entry point against a fixture reproducing the issue's exact scenario literal, kind row, and gen-shaped stub (the assessment itself deferred reproduction to this repo — done).
- The same kind-vs-prose collision class remains open for `theme`/`platform` kinds (no make-fallback lane exists for them); recorded as a follow-up in fix.md, intentionally not expanded here.
- `.specify/feature.json` is pinned to this bug directory for the audit; reset after the PR stage (it only matters for zfa-engine feature resolution, which this repo does not use).

## Recommendation

Close the bug — verified end-to-end: the reproduction flips from the issue's exact `generation-error` to certified green through the view lane, no regressions in the tdd plugin's 879-test fast tier or the #939 lane, mutation-pinned against re-escape. Proceed to `/skill:speckit-bug-pr slug=widget-func-verb-routing`.
