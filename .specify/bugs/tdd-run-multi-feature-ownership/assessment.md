# Assessment: `zfa tdd run` multi-feature ownership conflict (issue #801)

- **Slug**: tdd-run-multi-feature-ownership
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/801
- **Verdict**: valid — mechanism already fixed on master; closure evidence was missing
- **Severity**: high

## Report

The reporter ran `zfa tdd run` on a second feature in the same project
(v6.1.0, macOS) and the second feature's very first gen step died with
`OwnershipConflict: test file ".../test/tdd/a1_test.dart" exists on disk but
the registry has no recorded ownership`. The gen artifact paths were flat
(`test/tdd/<id>_test.dart`, `lib/tdd/<id>_subject.dart`) while the artifact
registry is per-feature (`specs/<feature>/tdd/artifacts.json`), so feature
N+1's gen hit the FR-008 guardrail against feature N's artifacts: two
features could never coexist.

## Timeline (verified from the repository)

- v6.1.0 tagged 2026-08-28 (5b9f35d9) — what the reporter tested. Flat gen
  layout; the bug is fully present.
- Issue #801 filed 2026-09-02T11:29Z.
- **#827 fix merged 2026-09-02T18:31Z** (447ac1ac, PR #869: "namespace TDD
  artifacts by feature-slug") — roughly 7 hours AFTER the issue was filed,
  with follow-up bd535c07. The reporter never saw this fix.
- No commit or PR references #801; the issue was never verified against the
  fix and stayed open.

## Root cause (confirmed)

`gen_command.dart` computed feature-agnostic artifact paths while
`ArtifactRegistry` is per-feature. The FR-008 ownership preflight is
CORRECT — it refused a file the second feature's registry did not own. The
defect was the flat path convention, fixed by #827's per-feature-slug
namespacing (`test/tdd/<feature-slug>/`, `lib/tdd/<feature-slug>/`), plus
`zfa tdd migrate-paths` for legacy flat projects (the issue's workaround
made manual).

## Empirical verification (this session, real CLI)

1. **Pre-fix reproduction (RED)** — a worktree at 447ac1ac^ (b6afda42, the
   commit just before the namespacing fix), seeded with the issue's two
   features (001-app-bootstrap + 004-dependency-injection, same behavior
   ids A1/A2), both test lists present before either run:
   - run 1: `result=complete`, exit 0 (matches the issue's "first run
     succeeds");
   - run 2: `[run] A1 gen -> error` → `OwnershipConflict: test file
     ".../test/tdd/a1_test.dart" exists on disk but the registry has no
     recorded ownership` → `result=stopped ... stopped_at=A1:gen`, exit 1.
     This is the issue's signature verbatim (evidence: red_log.txt).
2. **Post-fix (GREEN, master lineage)** — the same journey on this branch:
   - run 1: `result=complete`, exit 0;
   - run 2: `[run] A1 gen -> ok`, verify-red certified, artifacts namespaced
     under both features, both registries correct, no ownership conflict
     anywhere (evidence: e2e_branch_log.txt + green_log.txt).
3. **Honest remaining stop (a DIFFERENT bug)** — on master, feature-2's run
   then stops at `A1 make -> generation-error`: make's func spawn drops
   `--feature` (bug #877) and the (correct) func ambiguity guard refuses the
   id now registered in both registries. That defect is #877's scope, fixed
   by the open PR #888 — NOT re-fixed here (one bug, one PR). With PR
   #888's fix cherry-picked onto a scratch tree, the same two-feature
   journey completes end-to-end: run 2 `result=complete`, exit 0.

## Fix shipped by this PR

No production code change — the mechanism was already fixed by #827/#869.
What was missing for #801's closure:

- **The run-level regression pin**: the #827 tests pin bare `tdd gen`
  two-feature coexistence (gen_namespacing_827_test.dart); the issue's
  repro is the RUN driver, which spawns gen inside the full loop. New test
  `test/plugins/tdd/bug_801_run_multi_feature_ownership_test.dart` (slow +
  integration tier) drives the issue's exact journey through the real CLI
  and pins: feature-1 completes; feature-2's `[run] A1 gen -> ok`; no
  `ownership conflict`/`OwnershipConflict` anywhere; a run-2 stop is never
  at gen (`step=gen` / `stopped_at=<id>:gen` forbidden); both features'
  namespaced pairs + registries coexist; feature-2's registry never
  references feature-1's namespace. The pin holds both before and after PR
  #888 merges.
- **The bug record** (this directory) with the verified timeline and the
  issue-to-fix mapping, so the issue can close with evidence instead of a
  guess.

## Scope decisions

- No per-feature subdirectory work, no `--clean` flag, no cleanup pass: the
  issue's "Expected Behavior" options are alternatives; namespacing (the
  first option) is shipped and is strictly better than cleanup (nothing to
  clean — features don't collide).
- Legacy flat projects (created pre-#827, like the reporter's) migrate via
  the already-shipped `zfa tdd migrate-paths`; the registry conflict hint
  names that command (artifact_registry.dart `_legacyHint`).
- The make-stage func-ambiguity stop is #877's defect (open PR #888); it is
  documented in the test's header, not fixed here.
