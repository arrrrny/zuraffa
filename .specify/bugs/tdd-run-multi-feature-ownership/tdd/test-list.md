# TDD Test List — tdd-run-multi-feature-ownership (bug #801)

Branch: `fix/801-tdd-run-multi-feature-ownership` · Spec source: GitHub issue #801 (https://github.com/arrrrny/zuraffa/issues/801) — no bug records were committed in-tree; this issue.md/assessment pair is materialized from the API + the session's empirical verification

| # | Behavior | Test files | Tier | Pins |
|---|----------|-----------|------|------|
| B1 | The issue's exact journey: run feature-1, then feature-2 — feature-2's first gen never conflicts | `test/plugins/tdd/bug_801_run_multi_feature_ownership_test.dart` (real-CLI, slow+integration) | slow | two features seeded with the SAME ids (A1/A2); run 1 `result=complete` exit 0; run 2 `[run] A1 gen -> ok`; zero `ownership conflict`/`OwnershipConflict`; a run-2 stop is never at gen (`step=gen` / `stopped_at=<id>:gen` forbidden) |
| B2 | Both features' artifacts coexist, namespaced per feature-slug | same (post-run-2 assertions) | slow | `test/tdd/<feature>/a1_test.dart` + `lib/tdd/<feature>/a1_subject.dart` exist for BOTH features; each registry records its own namespaced paths and stamps its own feature name; feature-2's registry never references feature-1's namespace |
| B3 | The pin detects the regression class (mutation check) | same, against a flat-path mutant of `gen_command.dart` | slow | reverting gen to the pre-#827 flat paths (`test/tdd/<id>_test.dart`) makes B1 fail with the issue's verbatim signature (`stopped_at=A1:gen` + OwnershipConflict) |

## Success criteria (from issue #801)

- "The TDD cycle should support multiple features in the same project" via per-feature subdirectories — ALREADY SHIPPED by #827/PR #869 (the first of the issue's three alternative behaviors; the other two — a cleanup pass / a `--clean` flag — are moot when features cannot collide). PROVED by B1/B2 at the run level, the issue's exact repro surface.
- Closure evidence for the issue (filed 7h before the fix merged; never verified) — PROVED by the RED reproduction on 447ac1ac^ (issue signature verbatim) and the GREEN journey on this branch.
- Known honest stop documented, not hidden: without PR #888, feature-2's run stops at its first make (bug #877's func-spawn ambiguity, `stopped_at=A1:make`) — a different defect, tracked separately; B1 explicitly tolerates it while forbidding any gen/ownership stop.
