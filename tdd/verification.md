# tdd.verify — Issue #1685 review bot snippet uses non-existent `Directory.deleteRecursively`

- **Verified**: 2026-09-18, this session, on
  `fix/1685-review-bot-snippet-compilable` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/services/ci_referee/review_snippets.dart`
  (the fixed template catalog),
  `lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart`
  (the validation gate), the new
  `test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`,
  and the spec artifacts under
  `.specify/specs/1685-review-bot-snippet-compilable/`.
- **Engine path**: `zfa tdd verify --feature` ran for real this session —
  reported `gate: not_assessed` (the project is not zuraffa-wired: no
  `.zfa.json`, no behavior artifacts registered), so per the TDD
  extension's Step 0 the audit falls back to the LLM-guided path below.
  Every number in this file comes from a run executed in THIS session.

## Verdict: PASS

## 1. Test-first evidence (rubric Q1)

Two independent reds, both captured BEFORE the fix landed, recorded
verbatim in
`.specify/specs/1685-review-bot-snippet-compilable/red-evidence.md`:

1. **The bug's red** (the issue's exact failure, this session):
   the bot's snippet applied VERBATIM inside the standard wrapper →
   ```
   $ dart analyze build/1685_repro_snippet_test.dart
     error - 1685_repro_snippet_test.dart:21:22 - The getter 'deleteRecursively' isn't defined for the type 'Directory'. ... - undefined_getter
   3 issues found.
   ```
   (the two `info` lines are lint notes on the reproduction wrapper's own
   naming, not the snippet).
2. **The new seam's honest red**: the regression suite pre-implementation
   →
   ```
   00:00 +0 -1: loading .../spec_1685_review_bot_snippet_compilable_test.dart [E]
     Failed to load "..." :
     Error: Error when reading 'lib/src/plugins/tdd/services/ci_referee/review_snippets.dart': No such file or directory
     Error: Error when reading 'lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart': No such file or directory
   ```
   A compile-error red because the fix introduces a NEW seam: pre-fix
   there is NO template catalog and NO validation gate — which IS the
   root cause (nothing verified snippets between render and post).

Ordering caveat, stated plainly: the branch will carry the test and the
sources in ONE commit, so git history alone cannot show test-first
ordering; the session-recorded reds above are the evidence (the same
class of evidence the #1664 verification used for a new-seam fix).

## 2. Behavior assertions + would-they-catch-a-bug (rubric Q2, Q3)

Eight behaviors pinned in `tdd/test-list.md` (U-1685-G1a..G3b), each
asserting an OBSERVABLE gate outcome — never internals:

- The rendered shape pins the exact issue-workaround call
  (`deleteSync(recursive: true)`) and the catalog-wide deny of every
  verified-non-existent member (G1a, G1b).
- The gate is exercised against the HISTORICAL BUGGY SNIPPET VERBATIM —
  `addTearDown(_tmp.deleteRecursively)`, the real-world mutant — and must
  REJECT it twice: via the static deny-list scan (G2a) and via the REAL
  in-process analyzer resolve asserting `undefined_getter` (G2b). The
  fixed render must PASS the same analyzer check with zero errors (G2c).
  This is a deliberate-mutant kill: the mutant that shipped to
  arrrrny/zuraffa_browser#165 dies at both layers of the gate.
- `validate()` layering (scan hit short-circuits before the analyzer) and
  the posting gate itself (`postableSnippet` returns compiled-verified
  code; unknown ids throw) close the contract (G2d, G3a, G3b).

Mutation audit: `zfa tdd verify` reported `mutation_was_run: false`
(no behavior artifacts registered — this fix touches the reviewer tool,
not a generated feature). The historical-snippet mutant above is the
compensating deliberate mutant, and it is the one the issue shipped in
the wild.

## 3. Requirement coverage (rubric Q4)

- SC-1 (fixed shape, no deny-listed member anywhere) → U-1685-G1a, G1b.
- SC-2 (gate rejects the historical snippet; fixed render compiles for
  real) → U-1685-G2a, G2b, G2c, G2d, G3a.
- SC-3 (template audit) → `.specify/specs/1685-review-bot-snippet-
  compilable/template-audit.md`: 1268 dart files under `lib/` swept for
  the deny-list members — ZERO offenders (every hit is the deny-list
  itself or the gate/template documentation naming the non-existent API);
  per-site emitter inventory (route table test builder, behavior test
  writer, platform harness writer, scratch tmpdir, verdict renderer,
  persistence harness) shows only valid API references
  (`addTearDown(router.dispose)`, `dir.delete(recursive: true)`).
- SC-4 (honest red → green; guard suites unmodified) → reds in §1,
  greens in §4; the ci_referee posting-semantics suites pass unmodified.
- SC-5 (analyze + format gates) → below.

## 4. REAL runs in this session (post-fix, on this branch)

```
$ dart analyze lib test                       → No issues found!
$ dart analyze <the 3 changed dart files>     → No issues found!

$ dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart
  → 00:11 +8: All tests passed!               (8/8 — U-1685-G1a..G3b)

$ dart test test/plugins/tdd/services/ci_referee/
  → 00:01 +35: All tests passed!              (35/35 — posting semantics
                                               untouched: poster, verdict
                                               renderer, golden workflow,
                                               failure artifacts, gate,
                                               provenance)

$ dart format --output=none --set-exit-if-changed .
  → Formatted 2948 files (0 changed)          (exit 0 — zero drift
  repo-wide; the example/ resolution warning is the Flutter-less
  sandbox, not drift — same note as the #1664 verification)

$ dart analyze             (whole repo, for the record)
  → 208 issues — 200 errors ALL from packages/ sub-workspaces with
  unfetched deps (packages/zuraffa_graphql, packages/zuraffa_storage, …:
  uri_does_not_exist for their own package deps), PRE-EXISTING, in files
  this fix never touches; `dart analyze lib test` — the surface this fix
  lives on — is CLEAN.

$ zfa tdd verify --feature 1685-review-bot-snippet-compilable
  → gate: not_assessed (not zuraffa-wired; mutation_was_run: false) —
  the fallback audit above is the extension's prescribed path.
```

## 5. Worth keeping (rubric Q5)

The suite is deterministic (no network, no pub get, no build; the
analyzer resolve is in-process against this package's own package
config), fast (~11 s wall for 8 tests including two real analyzer
passes), and asserts through the public seam (`ReviewSnippets`,
`SnippetCompileCheck`, `SnippetDenyList`) — insensitive to internal
refactors of the gate. The wrapper cleanup is verified in-finally
(scratch dir removed every run; working tree stays pristine).

## Remediation tasks

None — verdict PASS.
