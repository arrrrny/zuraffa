---
feature: tdd-profile-quotes (bugfix #756, branch mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: f83ae5b6
behaviors: 4
proven: 4
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 100 # scope: changed branch, 2 deliberate mutants, both caught, both restored
mutants_survived: 0
suite: writer #756 group 3/3 + writer #680 guard 5/5, profile model 7/7; suite-wide counts in the shared verify section
---

# TDD Verification: #756 tdd-profile Commands bullets carry a stray trailing quote

**Verdict: PASS.** The shared render template no longer emits a stray `'`
outside the closing backtick on any of the four Commands bullets — for both
profile flavors, pinned by byte-exact assertions — and the dart profile's
single command now uses the same literal matcher (`--plain-name`) as the
flutter profile, closing the secondary drift the issue documents. The
regression tests were written FIRST and failed on the base commit with the
issue's exact defect bytes before the fix turned them green.

## Root cause (from issue, confirmed in source)

`lib/src/cli/writers/tdd/tdd_profile_writer.dart` `_render` (lines 168–171 at
`f83ae5b6`): each of the four Commands bullets closed its markdown inline-code
backtick and then emitted a literal `'` before the newline:

```dart
- Single test: `${p.resolveSingle(file: '{file}', name: '{name}')}'
- Whole file: `${p.resolveFile('{file}')}'
- Full suite: `${p.resolveSuite()}'
- Coverage: `${p.resolveCoverage()}'
```

Rendered, every bullet ended `--name "{name}"'$` (quote after the closing
backtick) — the issue's exact raw bytes. One shared template, so BOTH the Dart
and Flutter profiles were affected. The machine-readable Keys block further
down was correctly quoted, which is why tooling reading Keys was unaffected
while the human-readable Commands section (the block agents/humans copy from)
was malformed in every generated project.

Secondary drift confirmed at `lib/src/plugins/tdd/models/tdd_profile.dart:22,30`:
flutter `single` used `--plain-name` (literal substring matcher) while dart
`single` used `--name` (regex matcher). The TDD loop targets behaviors by
id/name, and any behavior name containing regex metacharacters breaks the dart
variant (`runner.dart` substitutes `{name}` and executes the template verbatim
via `SingleTestRunner.runSingle`).

## Remediation

1. **Primary**: dropped the stray `'` after each closing backtick in the four
   Commands bullets (`tdd_profile_writer.dart:168-171`). Line 163's Coverage
   stack bullet — which always rendered correctly — shows the intended shape.
2. **Secondary** (the issue's recommended alignment): dart `single` is now
   `dart test {file} --plain-name "{name}"`, matching flutter. The runner's
   `{name}` substitution feeds literal behavior ids/names; `--plain-name`
   treats them as substrings, so metacharacter-bearing names survive
   (`tdd_profile_test.dart` pins this with `U1: foo (bar) [baz]+`).

Regenerated profiles then match the already-repaired hand fixes in the two
consumer repos (`zuraffa_permissions`#4, `zuraffa_auth`).

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| U-756a: flutter Commands bullets end at the closing backtick, no stray `'` | PROVEN | writer test written FIRST; run on base → failed: got `` `flutter test {file} --plain-name "{name}"' `` (stray quote). Green after fix |
| U-756b: dart Commands bullets end at the closing backtick, no stray `'` | PROVEN | writer test written FIRST; run on base → failed: got `` `dart test {file} --name "{name}"' ``. Green after fix |
| U-756c: Commands bullets byte-identical to the profile command templates (Keys parity) | PROVEN | writer test written FIRST; run on base → failed at offset 42 (exactly the stray `'` position). Green after fix |
| U-756d: dart single uses the same literal matcher as flutter; metacharacters stay literal | PROVEN | model tests (literal matcher + metachar pin + parity) written FIRST; run on base → failed (dart used `--name`). Green after fix |

RED commands (before fix, recorded output):

```
dart test test/cli/writers/tdd/tdd_profile_writer_test.dart test/plugins/tdd/models/tdd_profile_test.dart
00:00 +9 -6: Some tests failed.
Failing tests:
  … issue #756 — flutter profile: bullets end at the closing backtick [E]
  … issue #756 — dart profile: bullets end at the closing backtick [E]
  … issue #756 — Commands bullets are byte-identical to the profile command templates [E]
  … dart profile resolves single with the literal matcher [E]
  … (+2 more: metacharacter literalness, matcher parity)
```

GREEN (after fix):

```
dart test test/cli/writers/tdd/tdd_profile_writer_test.dart test/plugins/tdd/models/tdd_profile_test.dart
00:00 +20: All tests passed!
```

End-to-end against the REAL rebuilt CLI (mutants restored, fix applied,
`scripts/rebuild.sh` first): `zfa tdd init` on a fresh temp Dart project
generates `.specify/memory/tdd-profile.md` whose Commands section, raw bytes:

```
- Single test: `dart test {file} --plain-name "{name}"`$
- Whole file: `dart test {file}`$
- Full suite: `dart test`$
- Coverage: `dart test --coverage`$
```

— every line `$`-terminated at the closing backtick, no stray quote, and the
Commands single matches the machine-readable Keys single.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW | The regeneration of previously generated profiles is left to the projects: the writer's overwrite guard accepts an existing dart-family profile as-is (#680 leniency), so projects with a malformed preset profile keep it until regenerated with `--force` or deleted. This matches the established #680 contract (enriched profiles must not be clobbered) and is how the two consumer repos already repaired theirs | tdd_profile_writer.dart write() family guard |

No `HIGH` smells in the new tests: byte-exact assertions with named `reason:`
on every expect, no conditionals, deterministic (temp dir per test, cleaned in
tearDown), existing fixture style and helpers reused (no bypassed test
utilities), and the model-level metachar pin asserts real runner semantics
rather than restating the implementation.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| re-add the stray `'` to the `- Full suite:` bullet in the render template | U-756a/b/c | No | 3 of the #756 writer tests failed (`+10 -3`); mutant restored exactly, suite re-run green |
| revert dart `single` to `--name` in `TddProfile.dart` | U-756d | No | 3 model tests failed (`+4 -3`: literal matcher, metachar pin, parity); mutant restored from saved copy, suite re-run green |

Sample: the change surface has two decision points (bullet template bytes,
dart matcher flag) — exhaustively sampled.

## Traceability (issue criteria → tests)

| Issue criterion | Test | Real entry point? |
| --- | --- | --- |
| Commands bullets carry no stray `'` (flutter profile) | writer U-756a | yes — asserts the file `zfa tdd init` writes, plus the rebuilt-binary end-to-end run |
| Commands bullets carry no stray `'` (dart profile) | writer U-756b | yes — same shared template, dart flavor asserted separately |
| regenerated Commands match the Keys block (no hand-repair needed) | writer U-756c (byte parity) | yes — writer output compared to the machine-readable templates |
| dart `single` aligned to `--plain-name` (no profile drift) | model U-756d (matcher parity + metachar pin) | yes — `TddProfile.dart.single` is the template the runner executes |

## What was not audited

- The example/ notes-package surfaces that `dart analyze` reports for the
  ROOT repo are outside this branch's diff (46 pre-existing issues, all in
  `examples/todo_tdd`, reproduced identically on the base commit via
  `git stash`).
- The runner's Keys/bullet parsing paths (issue #681/#680 machinery) — out of
  scope; the bullet fallback regex captures up to the closing backtick, so the
  stray quote never corrupted it, and no runner behavior changed here.
- Mutation-tool scoring (`mutation_test` package) — the profile marks it
  opt-in; deliberate mutants were used instead (2/2 decision points).

## Shared verify (branch-level)

- `dart analyze` (whole repo) → 46 issues, ALL pre-existing on the base commit
  (`git stash` re-run: identical 46), all confined to `examples/todo_tdd`; zero
  new issues from this branch.
- `tools/run_tests_chunked.sh` (fast suite, chunked, kernel cache cleared per
  chunk) → 67 chunks total: 2580 fast-tier tests — 2579 green in the chunked
  pass; the single failure (`func_command_test.dart` U-F3, temp-project
  subprocess flake) passed on the base commit AND passed 3/3 re-runs with the
  fix; 5 chunks SKIP (no fast-tier tests). No new failures attributable to the
  branch.
- `dart format .` (Dart 3.13.3) → the 4 changed files format-clean
  (`--set-exit-if-changed` exit 0); `git diff` after format shows only the 4
  intended files — zero formatting diffs (pre-existing unformatted files under
  `examples/` were left untouched, as they are outside this branch's scope).
