# TDD Verification — 1307-pubignore-benchmark-exclusion

- **Verified**: 2026-09-08T13:10:00Z
- **Verifier**: `/speckit.tdd.verify` fallback audit (zfa engine ZFA_MISSING;
  per `.specify/memory/tdd-profile.md`: no mutation tool wired → deliberate
  mutant sampling per the rubric)
- **Verdict**: **PASS**

## 1. Test-first evidence

| Behavior | RED proven before fix | Evidence |
|----------|----------------------|----------|
| B1 export guard (AC-1) | yes — 0/3 suite state after test written, before `.pubignore` touched | `tdd/cycle-log.md` §B1 RED: exactly the 8 `lib/zuraffa.dart` benchmark export targets missing from the would-publish set, all `(on disk: yes)` |
| B2 publish-set wall (AC-2) | yes | `tdd/cycle-log.md` §B2 RED: `benchmark_contract.dart is exported by lib/zuraffa.dart and MUST ship in the published tarball` |
| B3 hygiene (AC-3) | yes | `tdd/cycle-log.md` §B3 RED: all 8 unanchored patterns listed verbatim |

The failing test was written and executed against the unmodified (broken)
`.pubignore` in this session; the fix was applied only after RED was
recorded. Git history lands test + fix in one commit by design (one PR per
bug); the red-first evidence is the recorded session transcript, not
back-dated.

## 2. Red → Green

- RED: `dart test test/pubignore_export_guard_test.dart` → 0 passed / 3
  failed, each failing for the correct reason (1307 targets, not loader
  noise).
- GREEN: same command → `00:00 +3: All tests passed!` after anchoring the 8
  patterns.

## 3. Test-smell rubric

- No mocks/stubs of the subject: the guard walks the real tree and applies
  the real `.pubignore`.
- Deterministic: pure filesystem + string parsing; no network, no clock, no
  ordering dependence (concurrency irrelevant, single suite).
- No tautologies: B2 asserts both inclusion AND exclusion (harness stays out,
  sources ship); B3 asserts a negative property over the ignore file itself.
- Failure messages carry diagnosis (exact directive → resolved target →
  on-disk status), verified in the RED transcript.
- Scoped runtime: the suite runs in ~1s, no kernel-cache pressure.

## 4. Mutation testing (deliberate-mutant sampling)

- Mutant M1: reintroduce unanchored `benchmark/` (the 1307 root cause) at
  `.pubignore:31`.
- Result: **killed** — suite RED under the mutant (B1 + B2 + B3 all fail);
  restore → GREEN. Score: 1/1 killed, 0 survived, 0 timed out.
- Restoration verified: `git diff --stat` after restore = `.pubignore`
  only, 13 insertions(+), 8 deletions(-) — identical to the pre-mutation
  state.

## 5. Acceptance-criteria coverage

| AC | Covered by |
|----|-----------|
| AC-1 publish-time export guard | B1 |
| AC-2 gitignore-semantics regression wall | B2 |
| AC-3 unanchored-pattern hazard wall | B3 |
| AC-4 scope (only `.pubignore` + guard test) | `git diff --stat` (tracked diff = `.pubignore` only; test file is the sole new Dart file) — recorded in fix.md |

## 6. Authoritative gate corroboration

`dart pub publish --dry-run` post-fix: tarball tree contains
`lib/src/core/benchmark/` (5+ files listed incl. benchmark_contract.dart
7 KB, benchmark_runner.dart 17 KB, isolate_benchmark_runner.dart 6 KB) and
`lib/src/plugins/benchmark/`. 4 warnings + 1 hint, all pre-existing layout
advisories (tools/examples/docs renames; gitignored-but-checked-in files),
present before and unrelated to 1307.

## 7. Remediation

None required (verdict PASS).
