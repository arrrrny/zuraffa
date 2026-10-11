# TDD Cycle Log — gen-path-form-mismatch (#1397)

Deterministic fixtures: the fast-tier pins drive `ArtifactRegistry`
directly over a temp project (`<tmp>/specs/044-test-tdd-generation`,
the standard layout); the CLI pins drive the real CLI in-process
(`CliRunner.runCapturing`) over a temp project with one feature
(`100-feature-one`), mirroring `gen_namespacing_827_test.dart`.

## Cycle 1 — A1–A6 (the bug)

**RED (pre-fix tree, failing for the right reasons):**

```
$ dart test test/plugins/tdd/services/artifact_registry_test.dart

00:00 +11 -3: Some tests failed.

Failing tests:
  A1a preflight reuses when the prior record is project-relative and the caller offers the machine-absolute form [E]
    OwnershipConflict: the registry test path
    "/tmp/…/test/tdd/044-test-tdd-generation/b003_test.dart" does not match
    "test/tdd/044-test-tdd-generation/b003_test.dart".
  A1b preflight reuses when the prior record is machine-absolute and the caller offers the project-relative form [E]
    (same OwnershipConflict, inverse mix)
  A2 persists records in the portable project-relative POSIX form [E]
    Expected: not contains '/tmp/artifact_registry_test_OZTUKL'
    Actual:   '{"records":[{…"test_path":"/tmp/…/test/tdd/…",…}]}'

(A3 passes pre-fix as expected — raw string comparison already refuses
distinct paths; it pins the no-over-normalization guard.)
```

```
$ dart test --preset=all test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart

00:00 +1 -7: Some tests failed.

Failing tests:
  A4 re-gen of a relative-recorded behavior succeeds instead of refusing an ownership conflict [E]
  A5 flags machine-absolute records and prescribes migrate-paths [E]
  A5 the prescribed migration repairs the drift (doctor -> healthy) [E]
  A6 rewrite / dry-run / missing / idempotent — all four [E]

(A5's "a portable registry is healthy" control passed pre-fix as expected.)
```

**GREEN:** implemented in this cycle — see the A-row results below.

## Cycle 1 GREEN + Cycle 2 — relocated registries (the shipped fixture's shape)

**GREEN (Cycle 1, fast tier):**

```
$ dart test test/plugins/tdd/services/artifact_registry_test.dart
00:XX +15: All tests passed!          # 4 new A1/A2/A3 rows + 11 prior

$ dart test --preset=all test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart
00:01 +8: All tests passed!           # A4 re-gen reuse; A5 doctor drift +
                                      # closed loop; A6 rewrite/dry-run/
                                      # missing/idempotent
```

**Cycle 2 — RED (relocated registry, the real fixture's shape):** the
committed `example/specs/004-login-ui` registry records
`/home/z/my-project/zuraffa/example/...` (the authoring machine's root),
which exists on no other machine. Two reds drove the second
implementation pass:

```
$ dart test --preset=all test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart \
    --plain-name 'a relocated registry'
# migrate-paths reported missing=1 for artifacts that DO exist under the
# project root — a dead absolute record that doctor would flag forever:
#   MISSING for behavior "A1" ... the recorded test "..." does not exist
#   on disk. migrate-paths: migrated=0 refused=0 missing=1

$ dart test ... --plain-name 'a relocated registry is prescribed'
# doctor prescribed the DESTRUCTIVE reset for a relocatable record:
#   Expected: 'migrate'
#   Actual:   'reset'
#   (a relocatable record is form drift — the migration repairs it;
#    reset would drop the certified behavior)
```

**Cycle 2 — GREEN:** relocation probe (`probeRelocatedArtifact`, longest
project-root suffix that resolves to the recorded file, min
`<dir>/<file>` specificity) moved to the registry service; migrate-paths'
form branch repairs relocated pairs; doctor check 2 separates relocatable
records (prescription `migrate`) from genuinely missing artifacts
(prescription `reset`).

```
$ dart test --preset=all test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart
00:01 +10: All tests passed!

$ dart test --preset=all test/plugins/tdd/services/artifact_registry_test.dart \
    test/plugins/tdd/commands/bug_912_migrate_paths_package_uris_test.dart \
    test/plugins/tdd/commands/gen_namespacing_827_test.dart \
    test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart
00:14 +40: All tests passed!
```

**Dogfood — the real fixture, closed loop on real data:**

```
$ zfa tdd doctor 004-login-ui --project example --json     # BEFORE
verdict=fail exit_class=drift prescription=reset
drifts: A3/A4/A6/A7 — 8 × "<path> is recorded but missing from disk"
(foreign machine-absolute records resolve to a root that is not on this
machine; pre-existing fixture state, also present on master)

$ zfa tdd migrate-paths --feature 004-login-ui --project example
rewriting the recorded form for A3/A4/A6/A7:
"/home/z/my-project/zuraffa/example/test/tdd/004-login-ui/a3_test.dart"
  -> test/tdd/004-login-ui/a3_test.dart   (same for a4/a6/a7 + subjects)
migrate-paths: migrated=4 refused=0 missing=0 feature=004-login-ui   (exit 0)

$ zfa tdd doctor 004-login-ui --project example --json     # AFTER
{"verdict":"pass","exit_class":"healthy","drifts":[],
 "details":{"prescription":"none"}}                        (exit 0)
```

Post-migration fixture audit: `artifacts.json` carries zero
`/home/z/...` references; the cycle-log's parsed evidence fields
(`- test:` / `` `- command:` ``) carry zero absolute paths (the
migration rewrote the 47 log references of the migrated records); 12
inert prose/locator decorations for W1 (whose registry record was always
portable) keep the authoring machine's absolute form — unparsed by the
evidence store, untouched by design (append-only evidence beyond what the
command rewrote).
