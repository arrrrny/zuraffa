---
feature: tdd-theme-harness (bug #841)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 23b9ad68
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 80 # deliberate-mutant sample, 5 applied, 4 caught (1 equivalent mutant judged non-material); 2 initial survivors closed by pin strengthening
mutants_survived: 0 # at audit close; 2 transient survivors (M3, M4b) recorded below
suite: fast tier chunked 67/67 (62 PASS, 5 SKIP slow-tier-only) + slow-tagged integration 2/2; dart analyze tdd tree clean; dart format touched tree zero-diff
---

# TDD Verification: bug #841 — theme harness (light/dark scheme + typography as executable proof)

**Verdict: PASS_WITH_GAPS.** The fix's behaviors are pinned by tests that
landed in a test-only commit (`5b89fd9f`) BEFORE the fix commit, the red at
that commit is recorded with real output (the CLI refuses a theme row with
`malformed test list`, the pins fail to load), no HIGH smells, all four
remediation criteria are covered, and the deliberate-mutant sample ended
with zero survivors. The gaps are process-shaped: this audit was written by
the same session that wrote the fix and its tests (not independent), two
mutants initially survived weak presence-only pins and were closed by
strengthening those pins in the same session, and the EMITTED Flutter
harness text is pinned as text — it has not been executed on a real Flutter
host in this environment (this repo is pure Dart; executing the emission is
the target project's flutter-profile concern).

## Test-first evidence

Cycle-log red evidence is of the honest class for a missing generator
surface: the pre-fix binary cannot express the behavior at all, so the red
is (a) analysis/load failure at the pin layer and (b) a behavioral refusal
at the CLI layer — recorded with output in the cycle log and reproduced at
the test-only commit.

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| Reader: theme rows are expressible (`## Theme harness` header + `theme` kind cell) | PROVEN | pre-fix analyzer output recorded (3× `undefined_enum_constant`); at `5b89fd9f` the pins fail to load; fix commit lands the reader branch after |
| Writers: theme-kind gen emits the four-proof harness pair | PROVEN | pre-fix analyzer output recorded (`uri_does_not_exist`, `creation_with_non_type`); pins green at the fix commit (`+37`) |
| Gen dispatch: kind selects the writer pair (write path + staleness mirror) | PROVEN | at `5b89fd9f` the CLI integration test fails with REAL output: `zfa tdd gen: malformed test list — test-list.md line 7: table row outside an outer/inner loop behavior section` (`+0 -2`); green after the fix (`+2`) |

History shape: `5b89fd9f` (test-only, 3 files, +395) precedes the fix
commit (implementation + bug records). No existing test was weakened,
skipped, renamed out of a filter's reach, or excluded by config: the reader
and model changes are purely additive (new enum value, new header prefix,
new kind-cell branch); the gen-command change swaps unconditional writer
construction for kind-selected construction behind identical signatures.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | MED | Audit not independent: run by the same session that wrote the fix, its tests, and the mutants (rubric Hard Rule 2) | this report; every graded file re-read as written |
| 2 | MED | The dispatch behavior is covered only by the slow-tagged CLI integration test; the fast tier pins writers directly and would not catch a dispatch inversion alone | `gen_command_theme_test.dart` is `@Tags(['slow'])`; fast-tier run excludes it |
| 3 | LOW | The emitted-harness pins are text-pins (the emission is the product of this repo), which over-couple to emission phrasing; a reformat of the template is a pin edit | `theme_harness_test_writer_test.dart` throughout |
| 4 | LOW | Pre-existing formatter drift at `examples/mcp_demo/lib/src/mcp/tools.dart` on master is NOT this change's file and was left untouched (minimal-change discipline) — CI on SDK 3.13.1 may or may not flag it | `dart format --set-exit-if-changed --output=none .` lists it; `git status` does not |
| 5 | LOW | The sonner/toaster "themed" proof is a certification FLAG wired via the subject, not a structural widget-tree assertion — the sonner package (pub: sonner_flutter 0.0.1) exposes no stable themed-API to reflect on | emitted harness proof 1c; subject contract docs |

## Mutation results (deliberate mutants)

No mutation tool in the profile (`.specify/memory/tdd-profile.md`: mutation
tool opt-in, not wired); deliberate mutants per the rubric, one at a time,
each restored exactly and the suite re-verified green after every restore.
Sample: 5 mutants on the changed sites (all of them — the change is small).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| M1 — dispatch inverted (`== theme` → `!= theme`) | Gen dispatch | No (first run) | Caught by the CLI integration test: emission content pin fails (`+1 -1`) |
| M2 — `theme harness` section branch disabled (`else if (false)`) | Reader parsing | No (first run) | Caught by reader pins: section-header row becomes malformed (`+18 -1`) |
| M3 — proof-1 mode loop narrowed to `[ThemeMode.light]` | Dual-mode ShadTheme proof | YES, first run | Real finding: presence-only pin was satisfied by proof 4's `ThemeMode.dark` and proof 3's identical loop header. Pin strengthened to count `for (final mode in ThemeMode.values)` occurrences == 2; re-run → caught (`+17 -1`). Restored, green |
| M4 — whitelist gate prefixed with `false \|\|` | Hardcoded-color audit | Yes | EQUIVALENT mutant (`false \|\| X` ≡ `X`), no observable behavior change — judged non-material per the rubric |
| M4b — whitelist gate replaced with `false` (gate removed) | Hardcoded-color audit | YES, first run | Real finding: pin referenced `subject.themeConstantsFiles` but not the gate logic. Pins strengthened (`whitelist.any(` + `if (whitelisted) continue;`); re-run → caught (`+17 -1`). Restored, green |

At audit close: 0 surviving mutants. The two transient survivors were
test-strength gaps (weak pins), not production-code gaps; both closes are
in the fix commit and recorded in the cycle log.

## Traceability

The issue's four remediation bullets are the criteria; the consuming app's
SC-001..004 (ZikZak spec 002) map onto them.

| Criterion (issue #841) | Test(s) | Real entry point |
| ---------------------- | ------- | ---------------- |
| 1. Theme-kind behaviors → widget tests pumping the shell under both ThemeModes asserting ShadTheme values (primary/typography/sonner) | reader pins (2), writer pins group `proof 1`, CLI integration test 1 (asserts `ThemeMode.light`, `ThemeMode.dark`, `ShadTheme.of`, per-mode spec values present in emission) | `zfa tdd gen T1` via `CliRunner` (integration) + writer APIs (pins) |
| 2. Hardcoded-color audit as generated TEST (analyzer-backed scan of lib/, fail on raw Color(0x…) outside constants) | writer pins group `proof 2` (`parseString`, `Directory('lib')`, factory set, whitelist gate), CLI integration test 1 | same |
| 3. Golden captures per mode per platform; drift = exit 1 | writer pins group `proof 3` (`matchesGoldenFile`, platform+mode path segments, `--update-goldens` flow documented), CLI integration test 1 | same |
| 4. Theme-switch latency: pump-and-measure with certified tolerance, not flaky sleep | writer pins group `proof 4` (`tester.binding.clock`, `lessThan(spec!.themeSwitchTolerance)`, light→dark pump), CLI integration test 1 | same |

Both directions checked: no criterion without tests; no test tracing to
nothing (every pin traces to one of the four proofs or to the adopt/recovery
provenance contract from bug #840, which this fix must not break — pinned
via `matchesGeneratedTestShape`/`matchesGeneratedSubjectShape`).

## Environment honesty

This repository is a pure-Dart CLI that EMITS Flutter test code; the host
environment has no Flutter SDK. What this audit can and cannot claim:

- CAN claim: the generator's behavior end-to-end (CLI → emitted pair), the
  emitted text's syntax (analyzer parse, zero syntactic errors), the
  emitted text's contract content (pins), red/green history, mutant
  catches.
- CANNOT claim: that the emitted harness passes/fails against a real
  shadcn_ui host app; that goldens match a real captured baseline; the
  emitted code's semantic behavior under `flutter test`. That execution
  belongs to the target project's flutter profile (TddProfile.flutter) and
  is documented in the emitted header's PREREQUISITES block.
