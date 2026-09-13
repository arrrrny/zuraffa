# Bug Assessment: TDD doctor prescribes a nonexistent command form — migrate-paths silently discards the slug and cannot reach the bug directories

- **Slug**: 1573-doctor-prescribes-broken-migrate-paths
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1573
- **Related**: #1397 (path-form drift / relocate repair), #874 (cross-feature migrate prescription), #827 (migrate-paths command), #1471 (canonical feature references)
- **Verdict**: valid
- **Severity**: high

## Report (summarized)

`zfa tdd doctor` prescribes the recovery command for path-form drift as

```
zfa tdd migrate-paths <feature>
```

but `zfa tdd migrate-paths` declares only flags (`--feature`, `--project`,
`--dry-run`, `--json`). The prescription's positional slug lands in
`argResults.rest`, is silently discarded, and the command falls back to its
documented no-flag behavior: sweep EVERY feature registry in the project. In
the reported case the sweep rewrote an unrelated feature's registry while the
operator believed they were repairing one bug feature. Even the flag form the
doctor should have prescribed could not have helped: `_scanRegistries`
resolves every `--feature` value under `specs/`, so
`.specify/bugs/<slug>/tdd/artifacts.json` — the registry doctor itself
diagnosed — is unreachable and the prescribed command reports `migrated=0`.

## Symptom

On the shipped fixture `.specify/bugs/cycle-log-phantom-sections` (a
relocated registry: machine-absolute recorded paths from
`/Users/arrrrny/Developer/zuraffa`, artifacts present at the same
project-relative locations under the current root):

1. `zfa tdd doctor .specify/bugs/cycle-log-phantom-sections` correctly
   diagnoses the relocated registry and prints
   `--> fix: zfa tdd migrate-paths cycle-log-phantom-sections` — a command
   form the CLI does not accept.
2. `zfa tdd migrate-paths cycle-log-phantom-sections --dry-run` exits 0 and
   plans form rewrites for EVERY registry under `specs/` — the slug was
   dropped on the floor; a different feature's records get rewritten.
3. `zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run`
   reports `migrated=0` — the bug directory is never examined.
4. The path-form drift line renders the recorded value through the display
   normalizer (`_displayPath(cwd, p.normalize(...))`), so the operator sees
   a re-rendered view instead of the raw recorded string the migration will
   rewrite — grep-the-registry-for-what-the-line-shows stops working.
5. No test executes the prescribed command; the suite only asserts the
   prescription's string shape, so the drift sailed through CI.

## Reproduction

1. `zfa tdd doctor .specify/bugs/cycle-log-phantom-sections` → positional
   prescription (see Symptom 1).
2. `zfa tdd migrate-paths cycle-log-phantom-sections --dry-run` →
   `migrate-paths: migrated=5 refused=0 missing=0 feature=all` naming
   `specs/*` registries the slug never asked for.
3. `zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run` →
   `migrate-paths: migrated=0 refused=0 missing=0
   feature=cycle-log-phantom-sections`.
4. `dart test test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart`
   pre-fix → `+0 -6` (all six contract behaviors red; see
   `tdd/cycle-log.md`).

## Suspected Code Paths

- `lib/src/core/proof/proof_chain_checker.dart:703` — the proof chain's
  test-integrity drift prescribes `zfa tdd migrate-paths $feature`
  (positional form).
- `lib/src/plugins/tdd/commands/doctor_command.dart` — four prescription
  sites build the same positional form: foreign-owned migrate (bug #874,
  line ~230), relocated registry (2c, ~377), path-form drift (2e, ~484),
  import-resolution drift (2b, ~612).
- `lib/src/plugins/tdd/commands/migrate_paths_command.dart:871-887` —
  `_scanRegistries` hardcodes `p.join(cwd, 'specs', featureFlag)` and
  sweeps only `specs/`; `_run()` never inspects `argResults.rest`.

## Impact

Every operator who followed the doctor's prescription either silently
migrated the whole project's registries (data-corrupting side effect on
certified TDD state) or, when careful enough to add the flag themselves,
hit a `migrated=0` no-op that leaves the diagnosed drift in place. The
doctor's trust contract (`--> fix:` is an executable command, VISION §4
"errors are an API") is broken at both ends: the prescription does not run,
and the command it names cannot see the store the diagnosis came from.
