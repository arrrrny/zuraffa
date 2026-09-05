# TDD Verification — 0965-i18n-keyed-widget-contracts (issue #965)

**Generated:** 2026-09-05, FRESH from this session's actual run (never a stale
copy — FR-019 discipline). Written through the `/speckit.tdd.verify` fallback
audit: engine detection returned `ZFA_MISSING` (no `.zfa.json` at the repo
root), so the LLM-guided audit path applies per
`.specify/extensions/tdd/commands/speckit.tdd.verify.md`.

## Verdict: PASS (with recorded notes)

The feature's TDD discipline is proven: every behavior landed test-first with
captured red evidence, 43 new tests green across 5 suites, zero new analyzer
findings vs master, and the full fast suite passes chunked with no new
failures. Mutation audit: 5/5 targeted mutants killed.

## 1. Test-first evidence (git history)

Each task's RED commit carries ONLY tests (+ spec record); the GREEN commit
carries only the implementation:

| Task | RED (tests only) | GREEN (impl only) |
| --- | --- | --- |
| T001 spec contract | `93f9eb3e` spec(0965): spec record + T001 red — i18n key contract tests | `c59e0f03` feat(0965): i18n key contract, table, scaffold + ledger key kind |
| T002 generation | (suite added with T001's red commit; new suite file `bug_965_view_i18n_generation_test.dart` captured red BEFORE the generator change — see cycle-log) | `b6aaebd6` feat(0965): zfa tdd view emits t.<key> + scaffolds lib/i18n |
| T003 test shell | RED run recorded pre-implementation (compile red: `No named parameter with the name 'i18nKeys'`) | `73b0d268` feat(0965): slang test shell — resolved-key assertions |
| T004 ledger trace | RED run recorded pre-implementation (compile red: `Member not found: 'UiLedgerBuilder.untracedHardcodedStrings'`) | `20f6af66` feat(0965): ledger traces t.<key> per row + untraced-surface violations |
| T005 expansion tier | RED run recorded pre-implementation (compile red: missing `i18nExpansion`) | `accf0c9c` feat(0965): expansion locale tier — base + de pumps |

## 2. Red-phase evidence (cycle-log)

`specs/0965-i18n-keyed-widget-contracts/tdd/cycle-log.md` records each cycle's
behavior, classification (compileError for missing capability, assertionFailure
for the generator still pinning EN literals), command, exit code, and output
excerpt. All reds are honest: no skip, no placeholder-green, and the T002 red
run shows the zero-drift EN-fallback cases ALREADY green before the generator
change (the correct baseline behavior).

## 3. Test-smell rubric (applied to the 5 new suites)

- **No unconditional placeholders**: every test asserts a content contract
  (`contains`/`isNot` on generated artifacts or parsed models); no
  `expect(true, isFalse)`, no vacuous finders.
- **No sleeps / no wall-clock dependence**: all suites are content-level or
  deterministic-CLI drives; the two gen-wiring suites rely on the house
  `TddFixture` (temp project + `dart pub get` best-effort), no polling.
- **Determinism proven**: byte-identical view + scaffold across two fixtures
  (US2); copy-edit survival byte-diff on the assertion line (US3).
- **Zero-drift guarded**: US2.AC3 / US3.AC3 prove non-keyed output is
  byte-identical to the pre-#965 templates (no import, no locale pin, quoted
  EN literals) — the non-i18n host regression surface is pinned by tests.
- **Errors-are-an-API asserted**: malformed `key:` tokens refuse BEFORE any
  artifact write, with the row named and `--> fix:` present (both view and
  gen paths).
- **Suite isolation**: temp fixtures per test, `tearDown` disposal, `exitCode`
  reset (house convention).

## 4. Mutation results (targeted audit on changed files)

Scope note: the repo's `mutation-test.xml` lane is scoped to spec-041 files
(2400+ executions per mutant across the whole suite is out of this feature's
budget), so this audit applies 5 targeted source mutations to the NEW logic —
each must be KILLED by the 0965 suites. Harness:
`/home/z/my-project/scripts/mutation_audit_0965.sh` (exact-string mutation,
run, `git checkout` revert).

| Mutant | File | Mutation | Result |
| --- | --- | --- | --- |
| M1 | `i18n_key_contract.dart` | key grammar `+`→`*` (single-segment keys accepted) | KILLED (+25 −4) |
| M2 | `finder_taxonomy.dart` | `resolveKeys` never maps (`if (true) return`) | KILLED (+22 −7) |
| M3 | `finder_taxonomy.dart` | key-kind emission degrades to quoted EN text | KILLED (+23 −6) |
| M4 | `ui_ledger_builder.dart` | detector drops the key-anchor trace path | KILLED (+7 −1) |
| M5 | `i18n_key_contract.dart` | scaffold overwrite-check removed (clobbers existing translations) | KILLED (+27 −2) |

Audit-harness note: the harness's immediate post-revert runs twice reported
`−2` load errors (stale incremental kernel after in-place mutation). Outside
the harness the same 3-suite combination re-ran 3× consecutively green
(29/29 each), and the chunked suite below (fresh kernel per chunk) passed all
chunks — the anomaly is harness-local, not a product failure.

## 5. Acceptance-criteria coverage (spec.md → tests)

| Criterion | Proving tests |
| --- | --- |
| US1.AC1 keys parse with anchors | `bug_965_i18n_key_contracts_test.dart` (US1.AC1 ×2, US1.AC3) |
| US1.AC2 malformed keys refuse | same file (dot-less, digit-led, unquoted-anchor, row-named, conflicting re-declaration) |
| US1 zero drift on non-i18n rows | same file (Domain rows, no-key rows) |
| US2.AC1 view emits `t.<key>` + import | `bug_965_view_i18n_generation_test.dart` (US2.AC1 ×2) |
| US2.AC2 missing keys scaffolded (merge, no clobber) | same file (US2.AC2 ×2) |
| US2.AC3 EN fallback + no import | same file (US2.AC3 + empty-table scaffold inertness) |
| US2 determinism + refusal-before-write | same file (determinism, malformed-refusal) |
| US3.AC1 resolved-key finders + shell boot | `bug_965_test_shell_resolved_keys_test.dart` (US3.AC1 ×2) |
| US3.AC2 copy-edit survival | same file (assertion line byte-identical under anchor edit) |
| US3.AC3 zero drift | same file (no import/pin; quoted literal) |
| US3 keyed absence/enabled-state, routes never keyed | same file (3 tests) |
| US3 gen wiring + refusal | same file (gen CLI emits resolved-key test; malformed contract refuses before writes) |
| US4.AC1 `t.<key>` ledger rows DONE/NOT-DONE | `bug_965_ledger_key_traces_test.dart` (2 tests) |
| US4.AC2 untraced-surface violations | same file (5 tests: hardcode reported, accessor never flagged, anchor traced, text row traced, button children audited) |
| US5 expansion tier + de scaffold | `bug_965_expansion_locale_test.dart` (6 tests: tier present/absent/inert, gen flag, view scaffold, `.zfa.json` config) |

## 6. Verification run (this session)

```
dart analyze                     # 346 branch vs 345 master findings — the
                                 # single delta was an info lint in
                                 # behavior_test_writer.dart, fixed in
                                 # db5448fb; 0 NEW findings remain
dart format .                    # 1984 files, 0 further changes
git diff --stat                  # zero formatting diffs after commit
tools/run_tests_chunked.sh       # OK: all chunks passed (fast suite,
                                 # flutter-tagged tests excluded per
                                 # dart_test.yaml) — NO NEW FAILURES
```

## Remediation tasks

None — the gate passed. Follow-ups that are OUT of this spec's scope and do
not block: (1) wire `untracedHardcodedStrings` into the ledger's plan/verify
pipeline (075's outstanding T002); (2) the hosts' slang codegen runs via the
existing #834 loop — this spec only writes `.i18n.json` sources.
