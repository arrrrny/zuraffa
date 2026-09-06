# TDD Verification: 1140 — finder-kind taxonomy (plan kind column, gen declared-kind contract)

- **Slug**: 1140-finder-kind-taxonomy
- **Date**: 2026-09-06
- **Base commit**: `c7cf331a` (branch `fix/1140-finder-kind-taxonomy`)
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd verify` not applicable to a bug slug without `specs/<feature>/tdd/artifacts.json`, so per `speckit.tdd.verify.md` the fallback audit path ran — every number below is a real command output recorded in this session, none inferred)
- **Verdict**: **PASS**

## 1. Scope actually fixed (5 lib files, 3 test files)

| # | Wire-in (issue #1140) | Disposition |
|---|------------------------|-------------|
| 1 | plan outputs a `kind` column | **fixed** — `plan_command.dart::_render` widget table now `| id | behavior | kind | traces | state |`, cell derived via `FinderTaxonomy.kindCellFor` (presence / absence / route-outcome / enabled-state / sequence, `none` when no finder is derivable); acceptance + unit tables stay canonical 4-column |
| 2 | gen uses the kind to select the template | **fixed** — the declared cell parses into `BehaviorRow.finderKinds` (new, `test_list_reader.dart`), is carried on `Behavior` (`models/behavior.dart`, incl. the `--kind` override rebuild), and `gen_command.dart::_generate` reconciles it against `FinderTaxonomy.predictedKinds(description)`; in-sync rows generate the kind-matched templates, drifted rows are refused before ANY artifact write |
| 3 | verify-red refuses kind mismatch | **already shipped by #964** (`_certifyFinderKinds`, single + batch call sites) — re-proven here end-to-end through the NEW declared-kind chain rather than re-implemented |
| — | taxonomy helpers | `finder_taxonomy.dart` grew `predictedKinds` / `kindCellFor` / `tryParseKindCell` (strict: unknown token → null → malformed row naming the vocabulary) |

Supporting pin re-pointed (not weakened): `plan_gen_contract_test.dart`
"plan writes the canonical 4-column test list" asserted
`isNot(contains('kind'))` over the WHOLE file — the blanket form is
obsolete by the #1140 contract change. It now pins exactly the intended
shape: the 4-column header appears exactly twice (acceptance + unit),
the widget table carries the kind header, both loop sections present.

## 2. Test-first evidence (RED recorded against the unfixed tree, this session)

New suites:

- `test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart` (10 tests, CLI-observable so it compiles against the unfixed tree)
- `test/plugins/tdd/bug_1140_reader_kind_cell_test.dart` (10 tests, reader-level pins using the new row field — green-phase additions, they cannot compile pre-fix)

RED run against the unfixed tree (before any `lib/` change):

```console
$ dart test test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart
00:00 +2 -8: Some tests failed.
```

All 8 failed with the recorded defect shapes, e.g.:

```console
Expected: contains '| id | behavior | kind | traces | state |'
  Which: does not contain '| id | behavior | kind | traces | state |'
    (plan emitted the 4-column widget table)

Expected: contains 'finder kind'
  Actual: '❌ Error: Bad state: zfa tdd gen: malformed test list —
  test-list.md line 7: expected 4 columns (id/behavior/traces/state),
  found 5: "| A2 | shows the ''deal_list'' page after sign-in |
  route-outcome | AC-2 | PENDING |"'
```

(The 2 green tests in the red run are the back-compat pins — legacy
4-column rows already generated, and they must stay green.)

GREEN after the fix, same commands:

```console
$ dart test test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart \
            test/plugins/tdd/bug_1140_reader_kind_cell_test.dart
00:01 +20: All tests passed!
```

## 3. Mutant-kill check (rubric Q3)

`mutation_test` remains unwired in this repo (deliberate, per spec 041
follow-up), so the fix-removed mutant was used: `git stash push -- lib/`
reverts all 5 lib files to the base tree while both new suites stay
present:

```console
$ git stash push -- lib/
$ dart test test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart \
            test/plugins/tdd/bug_1140_reader_kind_cell_test.dart
00:00 +2 -9: Some tests failed.        # exit 1 — mutant killed
$ git stash pop
$ dart test ... (both suites)
00:01 +20: All tests passed!
```

Kill evidence: all 8 CLI-observable tests re-red against the mutant, and
the reader suite cannot even load (the declared field is absent) — 9 `[E]`
entries total, exit 1. The contract does not survive removing the fix.

## 4. Whole-repo verification (all real outputs, this session)

| Gate | Command | Result |
|------|---------|--------|
| Analyze | `dart analyze lib/ test/plugins/tdd/` | **0 errors, 0 warnings**; 103 infos — byte-identical count to the master baseline measured in a clean worktree (`/tmp/1140-master`, same SDK 3.13.3): master = 103, branch = 103. Every info pre-exists (generated fixture naming lints etc.). The two new test files contribute 0 issues. |
| Fast suite | `tools/run_tests_chunked.sh` semantics (byte-identical chunk selection via its own `DRY_RUN` plan, same `--exclude-tags flutter`, `/dev/null` stdin guard, inter-chunk kernel cleanup), executed by a resumable foreground wrapper (`scripts/run_chunked_resumable.sh` outside the repo — this sandbox kills detached processes) | **90/90 chunks: 3,490 passed, 0 failed** (84 passed chunks + 6 chunks skipped as "no fast-tier tests") |
| Chunk-split blind spot | the THRESHOLD=40 split excludes loose `*_test.dart` directly under over-threshold dirs (pre-existing design). `dart test test/plugins/tdd` (whole dir, covers its 56 loose files): **1,450 passed, 0 failed**. `dart test test/core/*_test.dart test/plugins/*_test.dart` (27 loose files): **415 passed, 1 skipped, 0 failed** | **1,865 passed, 1 skipped, 0 failed** |
| Format | `dart format` over every touched file (idempotent), then `dart format --output=none --set-exit-if-changed .` | The only remaining would-change files in the whole repo are 4 pre-existing on master (verified in the clean master worktree with the project's dart_style): `examples/mcp_demo/lib/src/mcp/tools.dart` + `examples/todo_tdd/test/tdd/{a1,u1,u3}_test.dart` — untouched by this PR, matching the #1139 precedent. **Zero formatting deltas from this change.** |

First wrapper invocation note (honesty): the first run of the resumable
wrapper failed all 91 pseudo-chunks with `No pubspec.yaml file found` —
a wrapper bug (it derived the repo root from its own path and cd'd to
`/home/z/my-project`). Fixed (`ROOT` hardcoded to the clone), state and
log reset, re-run from chunk 1. The FAIL lines from that aborted run
were wrapper artifacts, never counted as suite results.

## 5. Success criteria — proved vs not

- ✅ `zfa tdd plan` outputs a "kind" column in the widget behavior table — proved by plan tests over a 004-login-ui-shaped spec: AC "shows … hides …" → `presence, absence`; "navigates to the route 'deal_list'" → `route-outcome`; "while sign-in is in flight, shows … and disables …" → `presence, enabled-state, sequence`; post-copula "the button is disabled" → `enabled-state`; no-literal scenario → `none`; re-plan re-derives (no accumulation).
- ✅ `zfa tdd gen` uses the kind — proved by gen tests: in-sync `route-outcome` row generates the `_RouteRecorder.pushedNames` assertion and never `find.text('deal_list')`; absence row generates `findsNothing`; `none` row stays the scaffolded placeholder; drifted rows (both directions) refuse with declared/derived cells + `--> fix:` and zero artifacts; unknown token is a malformed cell naming the vocabulary.
- ✅ `verify-red` refuses a kind mismatch — shipped by #964 (`_certifyFinderKinds`, single + batch); composition proved end-to-end: plan kind → gen template → verify-red `classification=assertion certified=true` on the honest red.
- ✅ Corpus regression semantics ("new red failures appear when old behaviors are re-parsed through kind-aware gen") — the mechanism is proved at the writer level by the #964 suite (kind-matched assertions fail against inert stubs — the honest red) and re-proven here through the declared-kind chain (`verify-red composes with the declared kind`); the full fast suite stays green, so no FALSE reds were introduced for legacy lists (back-compat pins + the 3,490-test suite).
- ✅ Red → green evidence recorded in this session (8 red, 20 green across both suites).
- ✅ Mutant kill: fix-removed mutant dies (exit 1, 9 `[E]`).
- ✅ Whole-repo gates: analyze clean vs baseline, 90/90 chunks green, blind-spot loose files green, format clean (4 pre-existing example deltas on master, untouched).
- ⚠️ Not re-triaged: `.specify/bugs/1140-finder-kind-taxonomy/issue.md` did not exist in the repo; triage used the live issue body (fetched via the GitHub API) — quoted in `assessment.md`.
- ⚠️ Lane-split plans (`04-ENGINE.md` / `04-SKIN.md`) keep the 4-column shape (they render from `LaneRow`, not the plan table); a split feature's widget rows therefore parse as legacy (finderKinds null) and gen re-derives — behavior unchanged, only the drift-refusal gate is not expressed there. Documented, no crash risk (the reader still speaks the 4-column shape).
- ⚠️ Real flutter-lane execution (actual `flutter test` of a generated widget pair) is out of scope for the fast tier by repo design (`--exclude-tags flutter`); the generated pairs are validated by emitted-source content assertions, same tier as the #830/#912/#964 suites.
