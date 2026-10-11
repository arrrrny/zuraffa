# TDD Verification: 1259 — tdd engine lane certifies vacuous greens

- **Slug**: tdd-engine-vacuous-green (GitHub issue #1259)
- **Date**: 2026-09-07
- **Base commit**: `d3679e0f` (branch `fix/1259-tdd-engine-vacuous-green`)
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd verify` is not applicable to a bug slug without `specs/<feature>/tdd/artifacts.json`, so per `speckit.tdd.verify.md` the fallback audit path ran — every number below is a real command output recorded in this session, none inferred)
- **Verdict**: **PASS**

> Input note: `.specify/bugs/tdd-engine-vacuous-green/{issue,assessment}.md` are NOT
> present in the repo at the base commit (nor on any of the 449 remote branches);
> the bug context was sourced from the GitHub issue #1259 body (fetched via the
> GitHub API this session) and the remediation brief. The records' absence is
> flagged to the maintainers.

## 1. Scope actually fixed

Remediation requirement (from the assessment) → change → proving test:

| # | Requirement | Change (pipeline-owned only) | Test |
|---|-------------|------------------------------|------|
| 1 | `gen` derives subject signatures from the spec's declared Layer Contracts / Key Entities (params from the request entity, return from the result entity) — never invented `(String id, num value) -> int` shapes | `RoutingResolver` resolves signatures declared on DOMAIN/DATA rows (previously FUNCTION-row exclusive — the issue's `AuthRepo` under `**Domain**:` resolved no signature); new `unit_contract_shape.dart` turns the declared `Signature` into the compilable subject shape (scalar declared types verbatim, entity types degraded to `Object?` with the declared type preserved, param names derived); `SubjectWriter` renders the contract-derived unit stub with the declared-contract provenance header; `gen_command` resolves the declared signature via the same Feature-071 machinery `func` uses and threads it through the write + staleness re-render paths | U4, U5, U7 |
| 2 | `make` refuses vacuous greens — the unit-lane analogue of the widget lane's `scaffolded` refusal (#912 defect 3) | new `vacuous_guard.dart` (`vacuousGuardMarker` + `contentIsVacuousGreen`: strip guard-shaped `isNot(isA<UnimplementedError>())` expects — both the capture-guard and the `throwsA` variant — zero remaining expectations = vacuous); `make_command` step 3c refuses UNIT rows whose test is vacuous (`outcome=vacuous-green`, exit 1, no green evidence appended); kindless/legacy rows fail open; `MakeOutcome.vacuousGreen` added | U1 (negative), U2 (positive control), U3 (lane scope) |
| 3 | Green requires at least one assertion on the observable outcome named by the behavior description; the red surface may start at the guard | `BehaviorTestWriter` derives the assertion from the DECLARED contract first: scalar declared returns emit `expect(result, isA<T>())`; entity declared returns emit the guard carrying the vacuous-guard marker + remedy comment (so `make` refuses green until a real outcome assertion lands); parametrized subjects get representative scalar literals or `_argN()` placeholder helpers whose throw stays inside the capture (assertion-level red preserved); `func` renders the DECLARED shape with params (previously params were dropped) and refuses to rewrite a parametrized stub without a declaration (never invents an arity change) | U5 (scalar), U4 (entity marker), U6 (func declared shape, entity return stays red) |

Hard constraint respected: fixed ONLY through the generation pipeline (`gen`/`func`/`make` + their services); no hand-edits bypassing the contract. One PR per bug.

## 2. Test-first evidence (RED recorded against the unfixed tree, this session)

New regression suite: `test/plugins/tdd/bug_1259_vacuous_green_test.dart` (7 tests:
U1–U7, including two scope controls). RED run against the base tree (before any
`lib/` change):

```console
$ dart test test/plugins/tdd/bug_1259_vacuous_green_test.dart
00:22 +2 -5: Some tests failed.
```

All 5 fix-pinning tests failed for the RIGHT reasons (the exact bug shapes), e.g.:

```console
U1  Expected: <1>                Actual: <0>
    → make certified GREEN (exit 0) on a passing guard-only unit test
      (the func-scaffold dummy class) — the vacuous green, journal recorded
U4  Expected: not contains 'int subject_u_100()'
    → gen emitted the invented no-arg int shape for a behavior whose spec
      declared `AuthRepo: login(AuthRequest) -> User`
U5  Expected: contains 'bool subject_u_110()'
    → gen ignored the declared scalar return
U6  Expected: contains 'login(AuthRequest) -> User'
    → func output carried no declared-contract provenance
U7  Expected: not null           Actual: <null>
    → RoutingResolver resolved no signature for a DOMAIN row
```

The 2 controls (U2: outcome-asserted test certifies green; U3: acceptance rows
keep the legacy skip transition) passed in RED too — the failures key on the
bug, not the harness.

GREEN after the fix, same command:

```console
$ dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
00:14 +7: All tests passed!
```

## 3. Mutant-kill check (rubric Q3)

`mutation_test` remains unwired in this repo, so the deliberate-mutant protocol
was used (the #1139 precedent): mutant = "fix removed"
(`git stash push -- lib/` reverts all lib/ changes while the new suite stays).

```console
$ git stash push -- lib/
$ dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
+2 -5: Some tests failed        # all 5 fix-pinning tests killed the mutant
$ git stash pop
$ dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
+7: All tests passed            # restoration verified
```

The 2 scope controls survive the mutant (by design — they pin scope, not the
fix), so every failure in the mutant run is attributable to a removed fix line.

## 4. Adjacent suites re-run (only code touched by this change)

| Suite | Result |
|-------|--------|
| subject_writer_test.dart, behavior_test_writer_test.dart, behavior_test_writer_persistence_833_test.dart, routing_resolver_test.dart, func_command_test.dart, func_convergent_test.dart, func_declared_signature_test.dart | **+31 all pass** (one pin updated, see §6) |
| bug_912_template_self_hosting_test.dart, bug_912_literal_safety_test.dart, bug_964_finder_kind_taxonomy_test.dart, gen_command_ffi_835_test.dart, gen_command_platform_test.dart | **+52 all pass** |
| bug_1162_bug_subject_green_path_test.dart, bug_1162_subject_shape_test.dart | all pass (13 + skip-path tests) |
| bug_890_gen_project_autodetect_test.dart | **+9 all pass** |

`dart analyze` over all changed files: **No issues found**.
`dart format` gate: **0 remaining diffs** after `dart format .` on the changed set.

## 5. Pre-existing failures flagged (unrelated to this PR)

The repo's slow-tier make suites fail in this environment on BOTH the base tree
and the fixed tree (byte-identical failure lists, proven by running the suites
twice via `git stash`):

- `make_command_test.dart` — 31 failures (base = fixed, list diff empty)
- `make_command_1036_test.dart` — 3, `make_command_declared_071_test.dart` — 1,
  `make_command_strict_071_test.dart` — 1 (base = fixed, identical)
- `gen_command_test.dart` — 1 ("registry composite third segment"),
  `gen_command_theme_test.dart` — 1 (base = fixed, identical)

Root cause (environment, not this PR): the fixtures resolve `test 1.32.0` under
Dart 3.13.3; the fixture suite baseline reports `baseline exit: 1, failed: 0`
(the suite guard's compact-transcript parser predates this reporter's output
shape), so the baseline snapshot is refused before generation. None of these
suites exercise the #1259 surfaces differently from base; each was re-run on the
clean base tree this session and produced the identical list.

Success criteria PROVED vs not:

- gen derives signatures from declared Layer Contracts — **PROVED** (U4/U5/U7 + mutant kill)
- make refuses vacuous greens — **PROVED** (U1 negative + U2 positive control + mutant kill)
- ≥1 observable-outcome assertion required for green — **PROVED** (U2/U5 + the marker flow U4)
- Deterministic `zfa tdd verify` (mutation_test) — **NOT APPLICABLE** to a bug
  slug without `specs/<feature>/tdd/artifacts.json` (repo-wide: mutation_test is
  unwired per spec 041 follow-up); the deliberate-mutant protocol (§3) substitutes.

## 6. Behavior change of record (one existing pin updated)

`func_declared_signature_test.dart` pinned the PRE-#1259 declared rendering
(`bool subject_u_20()` — the declared param dropped). The remediation requires
the declared SHAPE (params from the request entity), so the pin now reads
`bool subject_u_20(Object? template)` (the declared `Template` param degrades to
`Object?` until the entity exists — the same compilability contract the contract
lane uses, issue #1007). This is the remediation applied, not a regression.

## 7. Disk housekeeping

Kernel caches (`.dart_tool/test/`, `/tmp/dart_test.kernel.*`), the TDD temp
fixtures (`/tmp/tdd_fixture_*`, `/tmp/zfa_gen_stale_*`, `/tmp/gen_command_test_*`)
were cleaned after each phase; final `df -h .` = 8.2G free of 9.9G (17% used).
