# TDD Verification — bug 1267 (tdd-run-make-wrong-working-dir)

- **Generated**: fresh, on the fix branch `fix/1267-tdd-run-make-wrong-working-dir`,
  from the ACTUAL runs executed in this fix session (never copied from a prior
  feature's verification).
- **Feature under audit**: bug-fix workflow (no spec feature dir) — audited
  through the `/speckit.tdd.verify` FALLBACK path (LLM-guided audit) because
  `zfa tdd verify --feature` requires a `specs/<feature>/tdd/test-list.md`,
  which a bug-record workflow does not carry.
- **Raw evidence committed alongside this file**:
  `tdd/red_evidence_1267.txt` (pre-fix failing run, captured verbatim) and
  `tdd/green_evidence_1267.txt` (post-fix passing run, captured verbatim).

## Verdict: PASSED (with mutation phase honestly deferred — see §5)

## 1. Test-first evidence (RED before GREEN)

The regression test `test/commands/project_root_autodetect_test.dart` was
written FIRST and executed against the UNFIXED tree (baseline d3679e0f).

RED run result (actual output, `/tmp/red_evidence_1267.txt` →
`tdd/red_evidence_1267.txt`):

```
00:00 +1 -3: Some tests failed.
```

3 failing tests, each failing for the RIGHT reason (the pinned bug contract):

1. `entity create from a project SUBDIRECTORY writes into the project root`
   — Expected exit 0; Actual exit 1 (the raw-CWD dependency check refuses
   although the project root with a valid pubspec sits one directory up).
2. `make from a parent without any project refuses instead of scattering`
   — Expected the canonical refusal; Actual: `✅ Generation complete: ✨
   lib/src/domain/usecases/catalog/item_usecase.dart` — **exit 0 with the
   usecase silently scattered into the rootless CWD** (the filed failure
   mode, reproduced verbatim).
3. `build from a parent without any project refuses instead of a lying
   dry-run success` — Expected the canonical refusal; Actual: `✅ Dry-run
   completed` with exit 0 and zero project validation.

The fourth test (`-C <project> keeps the exact pre-#1267 behavior`) passed
pre-fix — it is the constraint-3 regression guard and is expected to be green
in BOTH phases.

## 2. GREEN evidence

After the minimal fix (see `assessment.md` § "Chosen implementation"), the
same test file, unchanged, run in the same session:

```
00:38 +4: All tests passed!
```

(verbatim capture: `tdd/green_evidence_1267.txt`). The AOT CLI binary used by
the subprocess harness was rebuilt from the fixed sources by the helper's
staleness check, so the green run exercised the fixed code, not a stale
snapshot.

## 3. Suite results (targeted, per the cloud-agent contract: only code touched)

`dart analyze` on every changed file: **No issues found!**
`dart format` on every changed file: **0 files changed** (format gate clean).

| Suite (dart test) | Result |
|---|---|
| test/commands/project_root_autodetect_test.dart (NEW) | 4/4 pass |
| cli_runner_cwd_hardening + cli_runner_cwd_race + entity_convergent + entity_cli_exit_code + entity_help + project_context | 15/15 pass |
| make_command_test + make_command_xray_default (--preset=all) | 20/20 pass |
| build_command_unit_test + cli_runner_test (--preset=all) | 48/48 pass |
| test/cli (fast tier, full folder) | 200/200 pass |
| entity_receipt + build_yaml_guard + make_default_tier_plan + make_engine_plan | 26/26 pass |
| make_receipt + make_pubspec_sync + make_skin_flag + build_command_slang_stage (--preset=all) | 11/11 pass |
| **Total (targeted)** | **324 passed, 0 new failures** |

Pre-existing failures, honestly flagged (NOT caused by this fix):
`test/plugins/tdd/make_command{,_1036,_declared_071,_strict_071}_test.dart`
show **+9 −36 on the fixed branch and +9 −36 on PRISTINE master** (verified by
`git stash` → re-run → `git stash pop`): every failure is the sandbox being
unable to produce a trustworthy fixture suite baseline ("the suite baseline
did not produce a usable snapshot… baseline exit: 1, failed: 0"). Identical
before and after ⇒ environmental, unrelated to the fix. The full fast suite
was NOT run as one invocation (its ~6.5 GB kernel cache overflows this
10 GB disk — dart_test.yaml header), and `--preset=all` corpus/regression
suites that spawn `dart pub get` + `build_runner` per temp project were
likewise out of the disk budget; the targeted selection above covers every
changed file's consumers (runner-level, command-level, CLI-folder level).

## 4. Test-smell rubric (audited against the new regression test)

- **Observable-contract assertions** — every test asserts exit code + stdout
  contract + on-disk file location; no implementation-detail coupling. PASS
- **Hermeticity** — subprocess spawns via `runZfaSource` (the #506 pattern);
  temp fixtures created per-test and deleted in teardown; no process-global
  CWD mutation in the test process. PASS
- **Right-reason failures** — the RED phase failed on the pinned contracts
  (scatter / lying success / wrong refusal), not on harness accidents. PASS
- **No timing/ordering dependence** — no sleeps, no `expectLater` races;
  file-existence assertions are terminal states. PASS
- **Guard coverage** — the pre-existing `-C` behavior and the #764 help
  contract each carry an explicit regression assertion. PASS

## 5. Mutation results: NOT RUN (deferred, with reason)

The mutation phase (mutation_test) was NOT executed in this session. The
repo's own mutation config (mutation-test.xml) scopes mutations to the TDD
plugin + writers precisely because unscoped mutation drives 2400+ test
executions per mutant; running it over `cli_runner.dart` in this sandbox
(the same 10 GB disk that forbids the full suite) would exhaust the disk
budget the task's standing housekeeping rule sets. This is reported as a
deferral, not a pass. Suggested follow-up: run `zfa tdd verify`'s mutation
phase on a full-local baseline machine scoped to `lib/src/cli/cli_runner.dart`.

## 6. Acceptance-criteria coverage (the assessment's hard constraints)

| # | Constraint | Proof |
|---|---|---|
| 1 | Search upward for `pubspec.yaml` when `-C` is not provided; first found = project root | GREEN test 1: `entity create` from `my_app/lib` writes `my_app/lib/src/domain/entities/auth_request/auth_request.dart` (subdir → project root). Also proven for `make` by the same walk in `ProjectRoot.findOrNull`. |
| 2 | Clear error when no project root found | GREEN tests 2–3: exact text `No Flutter project found. Run from inside a project directory or use -C <path>.` + `--> fix:` line + exit 2 (ExitProtocol.usage); the pre-fix make SCATTER (exit 0 + files in the rootless CWD) is asserted away (`Directory(parent, 'lib')` must not exist). |
| 3 | Existing `-C` flag behavior unchanged | GREEN test 4: `zfa -C my_app entity create …` from the parent still exits 0 and writes into `my_app` — green in BOTH the RED and GREEN phases (guard test, byte-identical contract). |
| + | No new suite failures | §3: 324 targeted passes; the only failing group is byte-identical to the pristine-master baseline. |

## 7. Fix surface (pipeline-only, no hand-edited generated source)

- `lib/src/core/project/project_root.dart` — additive `findOrNull` +
  `noProjectFoundMessage`.
- `lib/src/cli/cli_runner.dart` — `_rootBoundGenerationCommands`,
  `_resolveGenerationRoot`, auto-detect wired into `run()` and
  `runCapturing()` (the same scoped-chdir machinery `-C` uses).
- `test/commands/project_root_autodetect_test.dart` — NEW regression test.
- `test/commands/entity_help_test.dart` — guard test's message assertion
  widened to accept the superseding canonical text (block + non-zero
  contract unchanged; documented in `assessment.md`).

Nothing under pipeline-owned generated templates was hand-edited.
