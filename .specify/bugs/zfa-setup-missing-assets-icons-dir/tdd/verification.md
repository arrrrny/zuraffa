---
bug: zfa-setup-missing-assets-icons-dir
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: session 2026-09-02 (branch fix/735-zfa-setup-missing-assets-icons-dir, base 49496d5, pre-commit)
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: unmeasured # no harness wired (tdd-profile); deliberate-mutant sampling: 3 applied, 1 caught, 2 survived and judged
suite: fast 2535 passed, 0 failed (chunked, 66 chunks, 5 empty slow-tier-only, exit 0); branding file 13/13; dart analyze clean; dart format idempotent
---

# TDD Verification: bug #735 — zfa setup must never leave a dangling assets/zuraffa_app_icons/ pubspec entry

**Verdict: PASS_WITH_GAPS.** Both regression tests carry recorded red-then-green
evidence from real `dart test` runs in this session, all three criteria derived
from `assessment.md` reach a test through the real entry point
(`BrandingWriter.writeFlutterBranding`, the exact method `zfa setup` calls at
`setup_command.dart:309-313`), the full fast suite (2535 tests, chunked,
disk-safe runner) passes with zero failures, and the killer mutant that
reintroduces the bug is caught. The gaps that keep this from `PASS`: the audit
was produced by the same session that wrote the fix, a full
`zfa setup --flutter` CLI end-to-end run was not possible (Flutter SDK
unavailable in this environment), and mutation strength is deliberate-sampling
only, with two surviving mutants judged contract-preserving (see Mutation
results).

## Audit independence disclosure

The same session authored the fix, the tests, and this audit. Mitigations
applied: the RED runs were executed and captured verbatim before any source
change landed (cycle log); every GREEN number below comes from a real
`dart test` process in this session, not from memory; three deliberate mutants
(Hard Rule 4 procedure) were applied one at a time to the changed logic,
observed, restored exactly (sha256-verified), and the tests re-run green after
each restore; every test and source file was re-read from disk before grading.

## Test-first evidence

| Behavior | Class  | Evidence                                                                                                        |
| -------- | ------ | --------------------------------------------------------------------------------------------------------------- |
| A1       | PROVEN | cycle log records the red (`+0 -1 ... [E] Expected: true Actual: false`, exit 1) before the fix; test and fix land in the same commit |
| A2       | PROVEN | cycle log records the red (`+0 -2 ... [E]`, exit 1) before the fix; same-commit test+source per repo convention |
| A3       | PROVEN | asserted inside A2's test body (`content.contains('assets/zuraffa_app_icons/')`); same red run covered it (the pre-fix pubspec DID contain the entry — the failing assertion was the directory) |

Diff check of what the change did to pre-existing tests: no assertion removed,
loosened, skipped, or renamed; U1–U11 keep their names, filters, and bodies
(the two new tests were appended in a new group). The pre-existing
`markTestSkipped('brand assets not checked out')` blind spot in U4/U5 is
untouched code — it is the environment that let bug 735 ship, and the new
tests deliberately do not replicate it (they never skip on absent brand
assets). Recorded as a LOW finding below, not a weakening.

## Findings

Ordered by severity, each with evidence and the fix.

| # | Severity | Finding                                                                                                                              | Evidence                                                        |
| - | -------- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| 1 | MED      | The two remediation mechanisms (copy-step create, pubspec-step create) are mutually redundant through the public API; the tests pin the contract, not each mechanism (see Mutation results M1/M2) | `lib/src/core/branding/branding_writer.dart:134,205`            |
| 2 | LOW      | U4/U5 still skip when brand assets are absent — the blind spot that let bug 735 ship remains in the pre-existing tests (out of scope for this fix; the new bug-735 group covers the condition) | `test/core/branding/branding_writer_test.dart:31-34,144-147`    |

No HIGH findings. Both findings carry remediation notes below.

## Mutation results

No mutation tool is wired in CI (`.specify/memory/tdd-profile.md`); Phase 4 ran
deliberate mutants on the changed logic, one at a time, each restored exactly
(sha256 verified: `4a40434025688784`) with the tests re-run green after every
restore.

| Mutant                                                                                  | Behavior | Survived | Judgment                                                                                                            |
| --------------------------------------------------------------------------------------- | -------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| M1: drop `destDir.createSync` in `_copyBrandAssetsToAssets` (restore silent skip)        | A1       | Yes      | Contract-preserving: `_updatePubspecAssets`'s defensive create still guarantees the dir exists before the entry. Redundant-mechanism removal, not a behavior change. Finding #1. |
| M2: drop defensive `createSync` in `_updatePubspecAssets`                                | A2       | Yes      | Contract-preserving, mirror of M1: copy-step create covers the flow. Finding #1.                                     |
| M3: drop BOTH creates (reintroduces bug 735)                                             | A1, A2   | No       | Caught: `+0 -2`, both tests fail with `Expected: true / Actual: false` — the exact dangling state from the issue.     |

Sampling disclosure: 3 mutants on 2 source sites; not exhaustive. The suite
level (2535 tests) was not re-run per mutant — the scoped branding file (13
tests) was the kill oracle; after the final restore the full file was re-run
green (13/13).

## Traceability

Criteria derived from `assessment.md` (Tests to add or update) — the bug
directory has no `spec.md`.

| Criterion                                                                                         | Tests        | End to end |
| ------------------------------------------------------------------------------------------------- | ------------ | ---------- |
| AC-1: after setup, `assets/zuraffa_app_icons/` exists on disk and pubspec references it            | A1, A2       | Partial — real production method (`writeFlutterBranding`), not full `zfa setup --flutter` (needs Flutter SDK) |
| AC-2: pubspec entry never dangles when the brand-asset source is absent (silent-skip regression)   | A2 (A1)      | Same entry point as `zfa setup`; source-absent condition simulated deterministically |
| AC-3: spec 053 contract unchanged — the assets entry is still written (create-dir, not omit-entry) | A2, A3       | Yes — pubspec content asserted directly |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Full `zfa setup --flutter` CLI end-to-end (with `flutter create` + a real
  `flutter test` run): not possible here — no Flutter SDK in this environment.
  The issue's exact downstream symptom ("Error: unable to find directory entry
  in pubspec.yaml") is Flutter tooling behavior; this audit proves the
  producing state (dangling entry) is impossible and the state Flutter needs
  (directory exists whenever referenced) is guaranteed.
- Mutation strength beyond the 3 sampled mutants; no harness score.
- `writeDartBranding`'s source-absent path has no dedicated test (pre-existing
  U5 skips when brand assets are absent); its behavior change (empty dir
  created) is covered only indirectly. Finding #2's remediation would close
  this.
- Performance, coverage percentage, and the slow-tier suites
  (integration/property/benchmark presets) — excluded by design on small
  agents per `dart_test.yaml` and the chunked runner's header.

## Remediation notes

Bug directories in this repo carry no `tasks.md` (matching the #682
precedent), so the findings' remediation is recorded here instead:

1. (Finding #1, optional) If the team prefers a single mechanism, drop the
   copy-step create and keep only the `_updatePubspecAssets` defensive create
   (assessment's Preferred), adding a source-absent Dart-path test for
   `writeDartBranding`. Prove with: `dart test test/core/branding/branding_writer_test.dart`.
2. (Finding #2, optional) Extend U4/U5 to run (not skip) with a fixture
   zuraffaRoot that has no brand assets, closing the blind spot that let bug
   735 ship. Prove with the same command.
