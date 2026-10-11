---
feature: tdd-visual-contract-no-surface
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: d3679e0f (tree state; fix uncommitted at audit time)
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 64/80 killed (80%, mutation_test --exclude-strings, diff-scoped whitelists over the 9 changed files, bug-1261 suite as the test command); full-string run 73/101 (72%) with 27 display-string survivors + 1 whitespace-equivalent; 0 behavioral survivors; all runs restored byte-identical (git diff md5-verified dd6a7bed65b618839fba0f856148bdc0 before/after every run)
mutants_survived: 0 behavioral (16 display-string/prose fragment mutants enumerated in Mutation results)
suite: affected area 115/115 green (bug_1261 suite 22 + plan_lanes_1000 + split_command_1000 + plan_skin_contract_1004 + gen_command fast tier + plan_gen_contract + 5 reader suites + bug_937 + bug_1140 reader, -j 1); gen_command slow tier 17/18 (1 pre-existing failure verified identically on the clean tree — see Findings); dart analyze on changed paths: no issues; dart format lib/ test/: 0 changed
---

# TDD Verification: visual-contract surface — golden-declarable in spec, adaptive_slots proposed for SKIN, no misleading scaffold comments (#1261)

**Verdict: PASS.** The bug's acceptance — a spec can DECLARE goldens per SKIN behavior and gen picks the gate up without the flag, plan proposes `adaptive_slots` for widget-kind SKIN lanes and warns "this skin has no visual contract" when the lane has neither slots nor goldens, and the widget scaffold header mentions goldens only when a `matchesGoldenFile` hook was actually emitted — is proven by 22 command-level + unit tests, all authored RED first and GREEN after the fix, plus a diff-scoped mutation audit with zero behavioral survivors. `/speckit.tdd.verify` was executed via its documented fallback path (Step 0: no `zfa` binary on PATH and no `.zfa.json` in the repo root → ZFA_MISSING → LLM-guided audit; the deterministic `zfa tdd verify` path needs a feature slug, and a bug fix has none).

## Test-first evidence

The suite was authored and run to RED BEFORE any fix code existed in this session: 15 of 19 tests failed for exactly the pre-fix signatures (compile-red on the absent `goldenIds`/`golden` API surface first, then behavioral red: `goldenIds` parsed as `[]` for every declaration form, no ` [golden]` row tag in 04-SKIN.md, exit 0 where golden drift must refuse 2, no "no visual contract" warning, no proposal print, `matchesGoldenFile` absent from flagless gen output, and the misleading golden comment PRESENT on hookless scaffolds). 4 tests were controls pinning behavior that must not regress (absent/`false` golden keys parse empty; untagged rows read `golden: false`; a goldenless SKIN lane writes no visual-contract section; the `--golden` flag path still emits hook + comment). Fix and test land in one PR as two commits (test-first commit, then the fix) per repo convention.

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — the `## Lanes` SKIN row grammar accepts `golden: true` (resolves to every behavior the lane declares, order-independent), `golden: [W1, W3]` (subset), `golden: false`/absent (nothing) | PROVEN | `bug_1261` parser group, 4 tests; RED: every declaration parsed to `[]` |
| B2 — the plan marks golden SKIN widget rows with the ` [golden]` tag in `04-SKIN.md` (canonical 4-column pipe structure preserved), renders a `## Visual contract` section naming the gated behaviors, and lists the gate in the meta-index golden column | PROVEN | plan golden-marks test; RED: no tag, no section, no column |
| B3 — the golden declaration rides HAND rows (the `W` ids the lane reserves) and ONLY the declared rows — a non-declared SKIN hand row and the derived widget row stay unmarked | PROVEN | hand-row test (W1 marked; W2 hand row + A1 derived row unmarked); RED: no marking at all |
| B4 — gen generates the `matchesGoldenFile` hook for a golden-marked widget row WITHOUT `--golden`, emits no spurious inert-golden warning, and the `--golden` flag keeps working (flag ORs in) | PROVEN | gen declared-golden test + flag test; RED: no hook without the flag |
| B5 — re-gen of a golden-marked row is idempotent: the staleness mirror renders the same golden bytes, no false "stub regenerated" rewrite, hook survives | PROVEN | re-gen idempotency test (byte-identical file, no regenerated note); the mirror previously rendered hookless and would have stripped the gate |
| B6 — a declared golden on a non-widget row is inert and WARNS (exit 0, no hook) — the hand-edited-row defense behind plan's refusal | PROVEN | inert-golden warning test; RED: silent |
| B7 — plan REFUSES golden declaration drift (exit 2, no artifacts): a golden id outside the lane's `behaviors:`, golden on a non-SKIN lane, golden on a non-widget SKIN behavior | PROVEN | 3 drift tests; RED: exit 0, artifacts written |
| B8 — plan GUIDES: a widget SKIN lane without slots gets the `adaptive_slots: [mobile, ios, android, macos]` proposal; a lane with neither slots nor goldens additionally warns "this skin has no visual contract"; declared goldens silence the warning; declared slots silence both; guidance never refuses (exit 0) | PROVEN | 3 guidance tests; RED: silent fall-through |
| B9 — `zfa tdd split` carries the golden surface through the one-shot migration: ` [golden]` marks on the migrated SKIN rows + a `## Visual contract` section + `golden_ids` in the receipt | PROVEN | split test; RED: no marks, no receipt field |

No pre-existing test was weakened or loosened — the test diff is additions only (`bug_1261_visual_contract_surface_test.dart`); the adjacent suites (lane plans, split, skin contract, gen command, all reader dialect suites, finder-kind suites) pass unchanged.

## Rubric notes (stage 2/5)

The tests assert the PIPELINE'S EMITTED ARTIFACTS (lane plan markdown, receipt JSON, generated test/subject source), never doubles or internals. Content-level assertions throughout (the bug #830 convention — no Flutter test execution), so a render regression fails the assert, not a snapshot diff. One deliberate non-assertion: golden PNGs are never executed (no Flutter SDK in the pure-Dart repo) — the hook's SOURCE is the contract, matching how bug #830 tests pin the golden lane.

## Findings

Ordered by severity. No HIGH findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | LOW | The `## Skin Contract` yaml block is NOT a golden carrier (the issue's "e.g." offered lane-row OR Skin Contract; the lane row was implemented). A `golden:` key inside `## Skin Contract` is rejected by the strict #1004 contract parser as unknown-key drift. Declaring goldens in the SKIN lane row is the supported surface; extending the typed contract model is a schema change deliberately out of a minimal-fix PR | `adaptive_skin_contract_parser.dart` strict key set; `## Lanes` grammar in `spec_parser.dart` |
| 2 | LOW | A `golden:` declaration in a CORE/BOTH lane row refuses (the golden gate is SKIN-only), so a BOTH-lane behavior cannot carry a skin-side golden via its BOTH declaration — the workaround is a SKIN hand row. The BOTH seam's skin copy is widget-kind and could in principle be golden-gated; refused until a bug asks for it | `_resolveLanes` golden-drift refusals (plan_command.dart); test "golden on a non-SKIN lane refuses" |
| 3 | LOW | run-skin's mode selection still keys on `adaptive_slots` only; a golden-only SKIN lane drives the generic path — but the generic path now GENERATES the golden hook from the plan row (remediation 1), and plan's proposal/warning (remediation 2) steers authors to declare slots for the conformance cycle. No silent fall-through remains: plan prints the no-visual-contract warning the bug says was missing | `run_skin_command.dart` mode selection; plan guidance output asserted in B8 |

## Mutation results

`mutation_test` 1.8.0 (the wired tool), scoped to the 9 changed files via per-file line whitelists generated from `git diff -U0` (`mutation-test-1261*.xml` + `tools/run-bug1261-tests.sh`, committed beside the fix for reproducibility; the wrapper mirrors `tools/run-tdd-tests.sh` hygiene — kernel-leak cleanup, `-j 1`, incremental cache kept). Test command: the bug #1261 suite (it exercises every changed file end to end). Sources were byte-identical before/after every run (git-diff md5 guard); two interrupted background runs were found to have left a mutant in the working tree — detected by the suite going red on pristine code, restored, and re-audited (this is why the guard exists).

| Run | Scope | Mutants | Killed | Survived | Verdict |
| --- | ----- | ------- | ------ | -------- | ------- |
| Pass 1 (chunks A/B/C/D, strings included) | 9 changed files, diff whitelists | 101 | 73 | 28 | remediation pass 1 → 4 REAL test gaps found |
| Behavioral (--exclude-strings, after pass-1 kills) | same | 80 | 64 (80%) | 16 | 0 behavioral survivors — every survivor is a single-char fragment inside a display/prose string (meta-index table cells and dashes, the `'-'` placeholder glyph, message prose tails, doc-comment path text); enumerated in the report |

Remediation pass 1 detail: the audit caught 4 genuine gaps in the NEW tests (not the fix) — the declarative-skip disjunction for the `## Visual contract` section (a broken skip would mis-parse the section's rows and kill `read()`), the hand-row golden gate conjunction (a `&&`→`||` mutant marked every SKIN hand row golden), the gen warning-gate disjunction (a spurious inert-golden warning went unasserted), and the whitespace-collapse contract of `GoldenMarker.extract`. Four killing tests were added; chunks re-run: reader chunk 18/19, commands chunk 45/56 → 46/56, all green.

## Traceability

| Issue #1261 criterion | Behaviors | Tests |
| -------------------- | --------- | ----- |
| 1. Goldens declarable per SKIN behavior in spec format; gen picks the gate up without the flag | B1, B2, B3, B4, B5, B6, B9, B7 | parser group (4), plan marks/section/meta-index, hand-row test, gen flagless hook + idempotency + flag path + inert warning, split marks + receipt, 3 drift refusals |
| 2. plan proposes adaptive_slots for widget-kind SKIN behaviors; warns "this skin has no visual contract" when neither slots nor goldens | B8 | 3 guidance tests (warning + proposal fire; goldens silence the warning; slots silence both; exit stays 0) |
| 3. Widget scaffold comment mentions goldens only when a golden hook was actually emitted | B4, B5, B6 | flagless scaffold asserts NOT contains "golden baselines are committed"/"test/tdd/goldens/"; flag and declared-golden scaffolds assert the comment present; route-outcome suppression rides the same `golden && !routeObserver` gate |

No criterion without a test; no test tracing to nothing.

## What was not audited

- The full fast-tier chunked suite (`tools/run_tests_chunked.sh`) was not run — cloud-agent constraint (the ~6.5 GB kernel-cache overflow the task brief warns about); the affected-area suites (115 tests across 13 files) plus the gen_command slow-tier file cover every changed file's consumers.
- One gen_command slow-tier test fails ("bug #871: the registry composite third segment is the PURE description") — verified failing IDENTICALLY on the clean tree via `git stash` (pre-existing, unrelated: registry composite naming, zero overlap with the golden surface). Flagged, not fixed (the auditor does not fix).
- 3 committed evidence files under `specs/1142-adaptive-layout-contract/tdd/evidence/` carry pre-existing `dart format` drift (formatted by an older dart_style); left untouched — they are committed evidence artifacts outside this fix's scope, and lib/ + test/ are format-clean.
- Mutation was diff-scoped (the honest scope for a bug fix — whole-file mutation of plan/gen would rate hundreds of mutants the bug suite does not target); the 16 behavioral-run survivors are display-string fragments, not covered-behavior gaps.
- The audit is same-session (not independent): tests authored by the same session that wrote the fix; the smell pass is self-graded against the rubric, re-reading every file cold before the verdict.
