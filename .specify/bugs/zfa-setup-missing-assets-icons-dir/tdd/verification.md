---
feature: zfa-setup-missing-assets-icons-dir (bug 735)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 1f61a9c0
behaviors: 5
proven: 4
likely: 0
test_after: 0
no_test: 0
not_applicable: 1
baseline: 1
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/2 deliberate mutants caught # scope: _updatePubspecAssets only (the file the bug changed); no mutation tool wired per tdd-profile
mutants_survived: 0
suite: 2,537 passed, 0 failed (chunked fast tier, 61 chunks, EXIT=0) ; branding file 15 passed / 0 failed
---

# TDD Verification: zfa setup dangling assets/zuraffa_app_icons/ pubspec entry (bug 735)

**Verdict: PASS_WITH_GAPS.** The branch's change (create the referenced
directory in `_updatePubspecAssets` before the pubspec entry is written or
kept) went through a recorded red→green cycle — three new regression tests
failed against the unfixed code with exactly the bug's on-disk signature and
passed after the fix — and all three acceptance criteria are covered through
the real public entry point (`writeFlutterBranding`). The gaps: the literal
end-to-end path (`zfa setup` → `flutter create` → `flutter test` printing
"unable to find directory entry in pubspec.yaml") was not executed in this
environment because no Flutter SDK is available here, and mutation strength
was sampled with deliberate mutants (no tool is wired), not measured.

## Context the verdict depends on

- `check-prerequisites.sh --json --paths-only` errors for bug-driven work (no
  `specs/<feature>` directory). FEATURE_DIR was resolved per the bug
  extension's per-bug layout:
  `.specify/bugs/zfa-setup-missing-assets-icons-dir/`.
- **This audit was not independent**: the same session wrote the tests, the
  fix, and this report (Hard Rule 2). Every cited run below was re-executed
  and re-read from its raw output for this report; no fresh-context auditor
  was available.
- The RED was real and pre-fix: the regression group was added and run at
  `505969d4` before `branding_writer.dart` was touched, and the failure mode
  matches the issue — the pubspec-entry assertion **passes** (the entry IS
  written) while the directory-exists assertion **fails** (the directory is
  NOT created). Full verbatim output in `cycle-log.md` (Cycle 1).

## Test-first evidence

| Behavior | Class          | Evidence                                                                                                                                     |
| -------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| U1       | PROVEN         | Cycle 1 red recorded (R1, `+8 -1`); test + fix committed together in `1f61a9c0` per the profile's same-commit convention                       |
| U2       | PROVEN         | Cycle 1 red recorded (R2, `+8 -2`); same commit                                                                                               |
| U3       | NOT_APPLICABLE | Freeze test: passes identically on both sides of the fix by design (no-injection path must stay side-effect free); still red-suite-stable      |
| U4       | PROVEN         | Cycle 1 red recorded (R4, `+9 -3`); same commit; covers the `flutter:` block-style injection branch                                            |
| A1       | NOT_APPLICABLE | Characterization baseline: the literal `flutter test` failure signature is produced by the Flutter toolchain, not this repo; not runnable here |

Existing tests were not weakened: the only test file touched is
`test/core/branding/branding_writer_test.dart`, and its diff adds one group
(R1–R4) without modifying any pre-existing U1–U11 assertion — no assertion
removed, loosened, renamed out of a filter, skipped, or excluded (verified by
reading the full file diff in `1f61a9c0`).

## Findings

| # | Severity | Finding                                                                                                                                                                                                                         | Evidence                                                        |
|---| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| 1 | MED      | Pre-existing, out of this bug's scope: the injection-anchor predicate `content.contains('flutter:')` can false-positive on a comment line mentioning `flutter:` (e.g. `# flutter: config below`), injecting a stray assets block. Unchanged by this fix; the same loose predicate guarded injection before it | `lib/src/core/branding/branding_writer.dart:222-231`            |
| 2 | LOW      | Pre-existing, out of scope: `examples/mcp_demo/lib/src/mcp/tools.dart` is not `dart format`-clean at `1f61a9c0` (92-line rewrite under the SDK 3.13.3 built-in formatter; likely formatted under a different dart_style version). Left untouched to keep this PR scoped to branding_writer.dart | `examples/mcp_demo/lib/src/mcp/tools.dart`                      |
| 3 | LOW      | The regression group's fixtures (`buildFlutterProject`, `absentSourceRoot`) are group-local rather than in a shared helpers path; consistent with the file's existing inline `Directory.systemTemp` style, so not graded Foreign style, but they would need extraction if a third consumer appears | `test/core/branding/branding_writer_test.dart:301-318`          |

No HIGH smells in the new tests: they assert observable on-disk state through
the public API (no doubles, no internals, no tautologies), use fresh temp dirs
with `addTearDown` cleanup (isolated, deterministic, fast — whole file runs in
under 1s), and name behaviors as observable results.

## Mutation results

No mutation tool is wired (tdd-profile). Deliberate mutants on the changed
surface, one at a time, each restored exactly (verified `git diff` clean) and
the suite re-run green before the next:

| Mutant                                                                                | Behavior | Survived | Judgment                                                                    |
| ------------------------------------------------------------------------------------- | -------- | -------- | --------------------------------------------------------------------------- |
| M1: directory-creation guard dropped (`if (false && !iconsDir.existsSync()) ...`) — reinstates the bug | U1, U2, U4 | No       | CAUGHT — `+12 -3`, exactly R1/R2/R4 fail with the issue's signature          |
| M2: injection disabled (`willInject = false && ...`) — entry never written              | U1, U4   | No       | CAUGHT — `+13 -2`, R1 and R4 fail on the missing pubspec reference; U2 correctly unaffected (its pubspec pre-carries the entry) |

Sampled: 2 of 5 behaviors' guards (both guard branches of the changed method).
Not exhaustive; recorded as sampling, per the rubric.

## Traceability

| Criterion                                                                                    | Tests        | End to end |
| -------------------------------------------------------------------------------------------- | ------------ | ---------- |
| C1: fresh setup leaves no dangling `assets/zuraffa_app_icons/` pubspec reference (issue body) | U1, U3, U4   | Partial — through the public `writeFlutterBranding` entry point; the CLI wrapper (`zfa setup` → `flutter create`) and the Flutter toolchain were not run |
| C2: an affected v6.1.0 project is repaired by re-running setup (issue "Workaround" made unnecessary) | U2           | Same level as C1 |
| C3: a pubspec without a flutter block is untouched and side-effect free                       | U3           | Same level as C1 |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- **The literal end-to-end repro** (`zfa setup --platforms=... proj` →
  `flutter test` → `Error: unable to find directory entry in pubspec.yaml`)
  was not executed: this environment has no Flutter SDK (the tdd-profile
  declares the root package pure-Dart). The RED encodes the same defect one
  level down, at the writer that produces the state the toolchain rejects.
- Mutation was scoped to `_updatePubspecAssets`'s two guard branches; the
  copy/icon/removal paths were not mutated.
- `tools/run_tests_chunked.sh` runs the fast tier (dart_test.yaml excludes
  `slow` and flutter-tagged tests); the excluded tiers were not run, matching
  the profile's guidance for feature-scoped work.
- Performance and dry-run/verbose UX behaviors: no criterion, no test, not
  assessed.
