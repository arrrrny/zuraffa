feature: tdd-133-widget-make-path (bug #939, slug tdd-133-widget-make-path)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at 31b3ad62 + fix/939-widget-make-path
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 3/3 # scope: the three changed sites (gate kind fix, make widget lane, view generator); deliberate mutants, no mutation tool in profile; all caught, restoration verified byte-exact (git diff --stat back to the fix diff + analyze clean + suites re-green)
mutants_survived: 0
suite: fast tier chunked 67/67 chunks OK (62 PASS, 5 SKIP), 0 failed — one environment flake (tdd/commands U-F4) failed once in sequence and was re-verified PASS twice (chunk standalone 133/133 x2); targeted: view 10/10, gate 5/5, make widget 4/4; slow-tier regression: make_command_test.dart 32 pass / 4 pre-existing master failures (baseline-verified on the stashed clean tree, byte-identical, NOT introduced here)

# TDD Verification: bug #939 — widget make path (view-builder generator) + composition-gate kind fix

**Verdict: PASS.** All five issue criteria are covered by tests that
landed in git history BEFORE the fix (test-only commit → fix commit),
the issue's exact CLI failure shape is reproduced at the real `zfa tdd
make` surface (pre-fix) and flips to certified green (post-fix), no HIGH
smells, and all three deliberate mutants were caught. The two LOW
findings below are environment- and process-shaped, neither weakens the
pinned contract.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B-939-lane — a widget-kind behavior's make reaches green through the view-builder lane (plan logs the widget lane, runs `tdd view <id> --feature <f>` then `build` in order, certifies the target test, exit 0) | PROVEN | RED recorded pre-fix: the real-CLI repro prints the issue verbatim (`outcome=unexpressible`, exit 1) and the test-only tree fails A14 (`+1 -3`); post-fix A14 green with the fake-bin dispatch log `[tdd view A-100 --feature ..., build]` and `## Cycle: A-100 (green)` in the cycle log; the real-CLI repro now exits 0 with green evidence appended |
| B-939-no-anchors — the view lane is contract-driven: a widget-kind make needs NO green unit anchors (the #830 dead-end with zero units is gone) | PROVEN | A15 red at the test-only tree (`+1 -3`), green post-fix with a single-row list and zero registered units |
| B-939-mislabel — the pre-#939 shape is unreachable: a widget make NEVER reports `is unit-kind`, never reports `outcome=unexpressible` at the planning stage, and the generation steps DO run | PROVEN | A16 red at the test-only tree; post-fix: `widget lane: view-builder generation` in the output, `tdd view A-100` in the dispatch log, no `is unit-kind` and no `outcome=unexpressible` anywhere |
| B-939-gate — the composition gate treats widget like acceptance (anchors resolve for a widget target) and names the row's ACTUAL kind in every refusal (theme-kind says theme-kind; unit-kind says unit-kind accurately) | PROVEN | Gate pins red at the test-only tree (`+4 -11` fast tier: widget-target-resolves, widget-zero-anchors→no-green-units, theme-kind-accurate all fail pre-fix); post-fix 5/5; the pre-fix mislabel is additionally pinned by the real-CLI repro output (`is unit-kind` for a `kind=widget` row) |
| B-939-view — `zfa tdd view` emits the deterministic minimal view: view-builder keeps the stub name and returns the skeleton; one Text per scenario literal (the paired test's find.text targets, #912 defect 3); one deterministic stand-in per DECLARED Presentation component (ShadInput→TextField, ShadButton→ElevatedButton labeled with the token); idempotent; refuses unrecognized shapes; never touches the paired test (044 ownership); byte-identical across runs | PROVEN | U-V1..U-V10 red at the test-only tree (the command does not exist pre-fix: `Could not be found` → every pin fails); post-fix 10/10; determinism pinned by U-V8 (two fresh fixtures, byte-equal renders) |

No existing test was weakened, skipped, renamed out of a filter's reach,
or excluded by config in this change. The only helper change
(`TddFixture.seedTestList` routing `kind: 'widget'` rows into the
`## Outer loop: widget behaviors` section) is additive and mirrors
`plan_command._render`'s section order byte-for-byte; every pre-existing
seedTestList caller is unaffected (62-chunk fast tier green).

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW | 4 slow-tier failures exist on master at 31b3ad62 and still fail at HEAD (3 in `make_command_test.dart`: the #657 message-format pin, U-829g, U-829h; 1 in spec-052 A11/U17); they are NOT introduced by this change — the full suite was re-run against the stashed pre-fix tree and failed byte-identically (same expected/actual, modulo temp-dir hash). This matches the master-drift family already documented in the #873 record (5 failures at its time, including the same #657 pin) | `/tmp/clean_make.txt` vs post-fix run; the #873 verification.md Finding 1 records the same drift family |
| 2 | LOW | One environment flake: `tdd/commands` chunk failed once inside the 67-chunk sequence (U-F4, func idempotency) and passed on both re-runs (file-standalone 20/20, chunk-standalone 133/133 twice). Not attributable to this change: the func surface is untouched, the same chunk passes in isolation, and the failure did not reproduce | `/tmp/chunk_results.txt` (re-verified note), two clean re-runs |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`:
"Mutation tool: none wired in CI"); deliberate-mutant sampling per the
rubric, one mutant at a time, restored exactly (byte-identical `cp` of
the pre-mutant file; `git diff --stat` re-verified back to the fix diff;
analyze clean; suites re-green after each restore). Sample: 3 mutants,
one per changed site.

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `composition_targets.dart` — the gate drops `&& targetRow.kind != BehaviorKind.widget` (widget refused again, mislabel restored) | B-939-gate | No | Caught by 2 pins in `composition_targets_widget_939_test.dart` (`+2 -2`): the widget-target-resolves pin and the widget-zero-anchors→no-green-units pin |
| `make_command.dart` — the `_compositionFallback` widget lane branch deleted (falls through to anchor discovery → acceptance-shaped refusal) | B-939-lane | No | Caught by 3 pins in `make_command_widget_939_test.dart` (`+1 -3`): A14 (green through the lane), A15 (no anchors needed), A16 (no mislabel, steps ran) |
| `view_command.dart` — the discovered Presentation components discarded before rendering (literal-only composition) | B-939-view | No | Caught by U-V1 in `view_command_test.dart` (`+9 -1`): the skeleton must compose the DECLARED components (TextField from ShadInput, ElevatedButton from ShadButton) |

## Rubric answers

1. **Tests first?** Yes — test-only commit precedes the fix commit; the
   RED state of every new pin is recorded at the stashed pre-fix tree
   AND the real-CLI repro (`tdd/red-evidence.md`), history corroboration
   per the rubric's expected shape (commits touching only test files,
   then the source commit).
2. **Behavior asserted?** Yes — every pin asserts the observable CLI
   contract (summary lines, exit codes, dispatch logs, cycle-log
   evidence, emitted file content), not doubles or internals.
3. **Would they catch a bug?** Yes — 3/3 deliberate mutants caught,
   restoration verified.
4. **Every requirement covered?** Yes — the issue's two defects map to
   the five behaviors above (structural make path: B-939-lane/-no-anchors
   /-view; _rowKind/gate: B-939-gate/-mislabel); the issue's hard
   constraints (determinism, handcraft seam, errors-are-an-API) are
   pinned by U-V8, the skeleton header contract in U-V1/U-V7, and the
   runner-error outcomes in U-V3/U-V4/U-V5.
5. **Worth keeping?** Yes — deterministic (no clocks, no network, temp
   fixtures disposed), fast (fast-tier pins < 12s; the slow-tier make
   pins ride the established fake-bin pattern), consistent with the
   neighboring make/compose/func suites they join.
