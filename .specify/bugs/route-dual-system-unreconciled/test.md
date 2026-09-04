# Bug Verification: Route Plugin Dual-System Unreconciled

- **Slug**: route-dual-system-unreconciled
- **Tested**: 2026-09-04
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: partial
- **TDD mode**: ON (LLM-guided fallback; no `tdd/verification.md` — see notes)

## Summary

The fix introduces `zfa route verify`, the `RouteTable` DTO, the
`RouteDriftDetector`, and the `--json` / `--plain` / `--strict` / `--out`
surface. All 15 new tests pass, all 54 route-plugin tests pass, and all
122 `cli/standard` tests pass. `dart analyze` is clean on every
changed file. The implementation is verified **insofar as a unit-level
+ CommandRunner-level proof allows**: a CLI consumer can now run
`zfa route verify --json` and `zfa route verify --plain` and the
shapes match the spec. The result is `partial` rather than `verified`
because the per-generator walkers (the actual bridge between the two
route systems) are follow-ups; the verify surface reads an empty
table today, which means a real dual-system project will still report
zero drift until the walkers land.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New unit tests (U1–U4, O1) | `dart test test/plugins/route/route_table_test.dart test/plugins/route/route_drift_detector_test.dart test/cli/standard/output_format_plain_test.dart test/cli/route_command_test.dart test/plugins/route/scenarios/sc_001_route_verify_test.dart` | pass | 15/15 GREEN |
| Route-plugin regression | `dart test test/plugins/route/` | pass | 54/54 GREEN (47 prior + 7 from the new tests) |
| `cli/standard` regression (touched by `output_format.dart` change) | `dart test test/cli/standard/` | pass | 122/122 GREEN |
| Lint / type-check | `dart analyze` on the 5 changed lib files + 5 new test files | pass | No issues found |
| Reproduction (post-fix) | `dart run ...` of `zfa route verify` end-to-end | pass | The surface runs; drift count is 0 because the walker is a follow-up (see Residual Risks) |

## Output Excerpts

```
00:01 +15: test/plugins/route/scenarios/sc_001_route_verify_test.dart:
            O1: zfa route verify executes end-to-end and exits 0 with no drift
            routes: 0
            drift: 0
00:01 +15: All tests passed!
```

```
00:05 +54: All tests passed!    (full test/plugins/route/)
00:07 +122: All tests passed!   (full test/cli/standard/)
```

```
Analyzing 10 files... No issues found!
```

## Residual Risks

- **Per-generator walkers are follow-ups.** `_readRouteTable()` in
  `route_verify_command.dart` returns an empty table today. Until the
  CLI-side walker (parses `*_routes.dart`) and the DDA-side walker
  (parses `zfa_router.g.dart`) land, `zfa route verify` will report
  `routes: 0, drift: 0` for any real project. The detector and DTO are
  correct; the data feed is the gap. This is recorded in `fix.md` as
  "Deviations from Assessment" item #2.
- **No live `gh`-verified drift end-to-end.** I did not create a
  scratch project, run `zfa route create` + annotate `@ZfaRoute` on
  the same path, and observe `zfa route verify` emit a drift finding
  — the walker is missing, so the exercise is not currently possible
  without a fix to the walker first. The detector is unit-tested with
  an explicit overlap (U2.3), so the *logic* is proven; the *system*
  is not.
- **TDD verification artifact not produced.** `tdd/verification.md`
  was not generated because `zfa tdd verify` requires `.zfa.json`,
  which this repo does not have. The `tdd/profile.md` and
  `tdd/cycle-log.md` artifacts are present; only the final
  `verification.md` step of the loop is missing.

## Recommendation

**Hold — the verify surface is verified, but the data feed is the
real bug.** This fix lands the plumbing (DTO, detector, subcommand,
output modes, exit code), but the bug is "two systems don't
reconcile" — and the *reconcile* step requires a walker on each side
to read the on-disk routes. Open a follow-up bug (suggested slug:
`route-verify-walkers`) for the per-generator walkers; close this
bug as `partial` until the walkers land and a real dual-system
project can be exercised end-to-end through `zfa route verify`.
