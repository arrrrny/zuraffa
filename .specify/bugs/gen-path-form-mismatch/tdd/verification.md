# TDD Verification: gen-path-form-mismatch (#1397) — registry path-form mismatch

- **Slug**: gen-path-form-mismatch
- **Date**: 2026-09-09
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd verify` unavailable for a bug slug — the audit path per `speckit.tdd.verify.md` used by prior bug audits, e.g. 1059)
- **Verdict**: **PASS**

## 1. Test-first evidence

**RED (Cycle 1 — recorded in-session against the unfixed tree, full output in
`tdd/cycle-log.md` §Cycle 1):**

```console
$ dart test test/plugins/tdd/services/artifact_registry_test.dart
00:00 +11 -3: Some tests failed.
  A1a preflight reuses when the prior record is project-relative and the caller
      offers the machine-absolute form [E]  → OwnershipConflict
  A1b preflight reuses when the prior record is machine-absolute and the caller
      offers the project-relative form [E]  → OwnershipConflict (inverse mix)
  A2  persists records in the portable project-relative POSIX form [E]
      (machine /tmp/... absolute path survives a write)

$ dart test --preset=all test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart
00:00 +1 -7: Some tests failed.
  A4 re-gen of a relative-recorded behavior refuses an ownership conflict [E]
  A5 doctor reports the mixed-form registry healthy, no prescription [E] (×2)
  A6 migrate form rewrite / dry-run / missing / idempotent [E] (×4)
```

**RED (Cycle 2 — relocated registries, the shipped fixture's real shape,
recorded in-session):**

```console
$ dart test --preset=all ...bug_1397_path_form_mismatch_test.dart --plain-name 'a relocated registry'
migrate-paths: migrated=0 refused=0 missing=1            [E]
# artifacts that exist under the project root reported MISSING — the
# prescribed migration could never repair a committed foreign-absolute record

$ dart test ... --plain-name 'a relocated registry is prescribed'
Expected: 'migrate'  Actual: 'reset'                     [E]
# doctor prescribed the DESTRUCTIVE reset for a relocatable record
```

**Mutant-kill check (deliberate mutant, recorded in this audit):**

```console
# mutant: _samePath reverted to the original raw-string comparison
# (p.equals(p.normalize(left), p.normalize(right)) — CWD-relative resolution)
$ dart test test/plugins/tdd/services/artifact_registry_test.dart --plain-name 'path-form normalization'
00:00 +2 -2: Some tests failed.
  preflight reuses when the prior record is machine-absolute … [E]  ← KILLED
  preflight reuses when the prior record is project-relative … [E]  ← KILLED
# (exactly the issue's misfire — the mutant re-creates the bug the suite pins)
# mutant reverted:
$ dart test test/plugins/tdd/services/artifact_registry_test.dart
00:00 +15: All tests passed!
```

Classification per `tdd-test-quality-rubric.md`: **PROVEN** — red output was
recorded against the unfixed tree in this session (Cycle 1 and Cycle 2), and
the regression tests land in the same commit as the fix (repo bug-fix
convention, cf. 1059's classification rationale).

## 2. Behavior assertions

`bug_1397_path_form_mismatch_test.dart` drives the real CLI in-process
(`CliRunner.runCapturing`) over a hermetic temp project; the registry rows
drive `ArtifactRegistry` directly over a temp project in the standard
`<root>/specs/<feature>` layout. Assertions target observable contracts only:
gen reuse vs conflict across path forms, doctor verdict/prescription lines and
the machine JSON (`verdict`/`prescription`/`fix`), migrate-paths summary line
(`migrated=/refused=/missing=`) and the persisted registry strings, file
bytes untouched by form rewrites, cycle-log evidence rewritten to the portable
form, and the fail-honest missing path.

## 3. Mutation results (rubric Q3)

The `mutation_test` dev-dependency is deliberately not installed in this repo
(commented out in `pubspec.yaml`; wired by a future task), so tool-driven
mutation is **NOT_ASSESSED** — stated rather than inferred. Deliberate mutant
as above: the single highest-value mutant (the bug's own root cause,
`_samePath` raw comparison) is killed by the two reuse rows; doctor/migrate
rows are killed by the Cycle-1 reds (recorded pre-fix).

## 4. Acceptance-criteria coverage (bug spec)

| AC | Evidence |
|----|----------|
| AC1 gen reuses across forms | registry rows A1a/A1b + CLI row A4 (`reused/reused`, no conflict) |
| AC2 doctor detects form drift + prescribes | CLI rows A5 (drift verdict, `prescription: migrate`, `--> fix: zfa tdd migrate-paths`) |
| AC3 existing artifacts unchanged by reconciliation | form-rewrite rows assert byte-identical files after rewrite |
| AC4 committed registries portable | A2 persistence row + relocated-registry rows + real-fixture scrub (dogfood: `migrated=4 missing=0`, doctor healthy, zero absolute refs in `artifacts.json`) |

## 5. Pre-existing failures (not caused by this fix)

`bug_874_doctor_cross_feature_adoption_test.dart`: 4 gen-recovery failures —
identical before and after the change (FormatException on non-JSON verdict
parse; tracked under `1250-ci-gates-red-master`, together with 5 in 840).
Zero delta attributable to this fix.

## 6. Reproduction (post-fix, real fixture)

```console
$ zfa tdd gen A5 --feature 004-login-ui --project example --widget-shell materialapp
ownership: reused/reused
gen: behavior=A5 verdict=reused kind=widget        (exit 0 — pre-fix: refused)
```
