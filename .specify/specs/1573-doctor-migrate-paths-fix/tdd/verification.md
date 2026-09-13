# TDD Verification — Spec 1573 (doctor prescription ↔ migrate-paths reachability)

- **Feature**: `1573-doctor-migrate-paths-fix` (issue #1573 — doctor
  prescribes the positional `migrate-paths <feature>` form the command
  silently discards; the flag form cannot reach `.specify/bugs/<slug>/`
  registries; the path-form drift line prints a normalized value)
- **Generated**: FRESH from the actual runs in this session (2026-09-13) —
  not a copy of a prior verification.
- **Command path**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks`
  → `/speckit.analyze` (cross-artifact SC↔P↔T mapping check, no drift) →
  `/speckit.tdd.plan` → `/speckit.tdd.run` (RED 0/4 → GREEN 4/4, evidence
  logs recorded) → `/speckit.implement` (sibling prescription strings +
  related-suite assertion updates) → this audit.
- **Scope note**: only the prescription strings, `migrate-paths` scope,
  argument handling, and the path-form drift-line rendering changed —
  migration mechanics (pair-atomicity, ownership refusals, fail-honest
  missing, cycle-log rewrites) are untouched.

## Verdict: **PASSED** (RED 0/4 → GREEN 4/4; neighbors green; analyze clean)

| Gate | Result |
| --- | --- |
| Live repro (pre-work, real repo fixture `.specify/bugs/cycle-log-phantom-sections`, HEAD 9254ec1d) | **CONFIRMED** — doctor prescribed `zfa tdd migrate-paths cycle-log-phantom-sections` (positional); positional run swept every specs/ registry (`migrated=92 refused=0 missing=2 feature=all`, dry-run); flag form reported `migrated=0` (bug dir never examined) |
| Red evidence (`tdd/red-1573.log`) | **4/4 new behaviors FAIL against HEAD** for the predicted reasons: P1 `Expected: 'zfa tdd migrate-paths --feature 1573-phantom-fence' / Actual: 'zfa tdd migrate-paths 1573-phantom-fence'`; P2 `Expected: <2> Actual: <0>` (silent sweep); P3 `migrated=0`; P4 drift line printed `machine-absolute (test/tdd/1573-phantom-fence/a1_test.dart)` — a relative path |
| Green evidence (`tdd/green-1573.log`) | **4/4 pass** post-fix, re-verified after `dart format`; #1397 file **10/10 pass** (whole file) |
| Neighbor suites | `bug_912_migrate_paths_package_uris` + `bug_969_json_verdict_envelope` (incl. the migrate-paths envelope) + `bug_912_template_self_hosting` + `proof_chain_command` = **42/42 pass**; `gen_namespacing_827` all green |
| Pre-existing failures (NOT this PR's) | 4 in `bug_874` gen `--adopt` verdict group + 5 in `bug_840` gen `--adopt`/reset verdict group — byte-identical sets verified by HEAD control runs (`git stash` → same tests fail → pop); the doctor cross-registry groups of the same files are green |
| `dart analyze` (7 changed files, pre- and post-format) | No issues found |
| `dart format` | Applied to the 7 touched files only; re-analyzed + re-run green after formatting |
| Live repro re-check (post-fix, dry-run, real repo) | doctor → `--> fix: zfa tdd migrate-paths --feature cycle-log-phantom-sections — ...`; flag form → `migrated=5 ... feature=cycle-log-phantom-sections` (the 5 bug-dir records, was 0); positional → `❌ ... takes no positional argument — pass the feature as a flag: zfa tdd migrate-paths --feature <name> ...`, exit **2** |

## Success criteria audit

- **SC-1** — Doctor emits `fix: 'zfa tdd migrate-paths --feature $feature'`
  on the `--> fix:` line AND the JSON verdict `fix` key (P1 asserts the
  exact string); sibling sites updated: `doctor_command.dart` single-owner
  foreign-owned / relocated-registry / path-form-drift / import-drift,
  `proof_chain_checker.dart` test-integrity import drift, `gen_command.dart`
  both foreign-owner verdicts; multi-owner branch stays flag-less (pinned
  by the UNCHANGED bug_874 :296-297 `isNot` guards). **MET**
- **SC-2** — `--feature <slug>` reaches `.specify/bugs/<slug>/tdd/artifacts.json`
  without a pin file (plain-name conventional probe; explicit
  `.specify/bugs/<slug>` and pin fallback route through
  `TddFeaturePaths.resolveWithPin`); the no-flag sweep repairs a specs/
  registry AND a bug registry in one run (P3: `migrated=2`, both feature
  names printed, both stored forms portable). **MET**
- **SC-3** — `zfa tdd migrate-paths <slug>` exits `ExitProtocol.usage` (2)
  with a message naming the `--feature` flag form and migrates nothing
  (P2); live CLI confirms exit 2 + usage output. **MET**
- **SC-4** — P1 tokenizes the `--> fix:` payload, executes the prescribed
  command via the runner (plus `--project` test plumbing), asserts
  `migrated > 0` via the `migrated=(\d+)` summary capture, asserts the
  stored recorded form is portable, and re-runs doctor → `healthy`. The
  prescription is verified by execution, not string shape. **MET**
- **SC-5** — The check-2e drift line prints the RAW recorded string
  (P4: drift lines contain the machine-absolute path and NOT
  `machine-absolute (<relative form>)`). **MET**

## Hard constraints audit

- Fix confined to: 8 prescription-string sites (4 doctor + 1 proof chain
  checker + 2 gen + the drift-line rendering), `migrate-paths` scope
  (`_scanRegistries` + resolver route), argument handling (`rest`
  rejection), and the test assertions that pinned the buggy string shape
  (bug_1397 ×3, bug_874 ×3 + two header comments). Migration mechanics:
  byte-identical. **SATISFIED**
- `dart analyze` with no new warnings: clean on all 7 changed files,
  pre- and post-format. **SATISFIED**
- Related suites green: #1397 10/10 (flag-form assertions), #874 doctor
  groups green with updated assertions and intact multi-owner guards.
  **SATISFIED**
- One PR, `Closes #1573`: see the branch `feat/1573-doctor-migrate-paths-fix`.
  **SATISFIED**

## Pre-existing failures observed (out of scope, documented for the maintainer)

HEAD (9254ec1d) already fails, independently of this branch (verified by
stash/pop control runs — identical failing test sets):

- `bug_874_doctor_cross_feature_adoption_test.dart` — 4 tests in the
  "zfa tdd gen recovery path refuses foreign-owned files" group
  (`--adopt` verdict envelope shape: `Expected: contains '"verdict":"refused"'`,
  actual refusal text printed without the envelope line).
- `bug_840_recovery_commands_test.dart` — 5 tests (gen `--adopt` shape
  refusal / audit / verdict + reset diff & verdict + unknown-feature
  refusal), same envelope-shape family.

Both clusters concern the `--json`/verdict emission of the gen `--adopt`
and reset paths — untouched here per the spec's hard constraints; filed
here as observed evidence only.

## Recorded evidence (excerpts — raw logs are `*.log`, gitignored)

Red run (`tdd/red-1573.log`, against HEAD 9254ec1d, 2026-09-13):

```
00:00 +0 -1: ... the prescribed migrate-paths command executes and repairs the diagnosed bug registry [E]
  Expected: 'zfa tdd migrate-paths --feature 1573-phantom-fence'
    Actual: 'zfa tdd migrate-paths 1573-phantom-fence'
00:00 +0 -2: ... a positional feature argument is rejected loudly ... [E]
  Expected: <2>
    Actual: <0>
  ... output was: ... no feature registry found under specs ...
  migrate-paths: migrated=0 refused=0 missing=0 feature=all
00:00 +0 -3: ... the flag form reaches the bug registry ... [E]
  Expected: contains 'migrated=1'
    Actual: 'migrate-paths: migrated=0 refused=0 missing=0 feature=1573-phantom-fence\n'
00:00 +0 -4: ... the path-form drift line prints the raw recorded value [E]
  Actual: '  drift: A1: the recorded test path is machine-absolute
           (test/tdd/1573-phantom-fence/a1_test.dart) — records must be
           project-relative to stay portable\n'
00:00 +0 -4: Some tests failed.
```

Green run (`tdd/green-1573.log`, post-fix + post-format, 2026-09-13):

```
$ dart test test/plugins/tdd/commands/bug_1573_doctor_migrate_prescription_test.dart
00:00 +4: All tests passed!
$ dart test --preset=all bug_1397_path_form_mismatch_test.dart
00:00 +10: All tests passed!
$ dart test --preset=all bug_912_migrate_paths_package_uris_test.dart
  bug_969_json_verdict_envelope_test.dart bug_912_template_self_hosting_test.dart
  proof_chain_command_test.dart
00:39 +42: All tests passed!
$ dart analyze <7 changed files>
No issues found!
```
