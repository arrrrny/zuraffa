# Cycle Log: bug #1573 — doctor prescribes a broken migrate-paths command

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- branch: `fix/1573-doctor-prescribes-broken-migrate-paths` at `db4db9a3`
  (master head)
- live CLI repro on the unmodified tree (the shipped fixture
  `.specify/bugs/cycle-log-phantom-sections`):
  - `zfa tdd doctor .specify/bugs/cycle-log-phantom-sections` →
    `--> fix: zfa tdd migrate-paths cycle-log-phantom-sections`
  - `zfa tdd migrate-paths cycle-log-phantom-sections --dry-run` →
    `migrate-paths: migrated=5 refused=0 missing=0 feature=all` (the
    bystander sweep: form rewrites planned for `specs/*` registries the
    slug never named)
  - `zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run`
    → `migrate-paths: migrated=0 refused=0 missing=0
    feature=cycle-log-phantom-sections`
- recorded: cycle 0, before any change

## Cycle 1: the prescription is executable, the bug dirs reachable, the positional loud (bug #1573)

- behavior: the six behaviors B1–B6 in `tdd/test-list.md` (prescription
  form + canonical reference; prescription execution heals the registry;
  pin resolution for a plain bug slug; loud positional rejection with a
  byte-identical bystander; sweep coverage of `.specify/bugs/`; raw
  recorded value on the path-form drift line).
- tests (new file
  `test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart`,
  fast tier so CI runs the executable-prescription contract):
  - fixture: temp project root; bug feature
    `.specify/bugs/1573-sample-bug` with a relocated registry (foreign
    machine root recorded, artifacts at the project-relative locations)
    and a resolving-absolute variant for B6; bystander `specs/` feature
    whose registry carries the resolving-absolute form of its own
    artifacts (the collateral-damage witness)
- red (real, pre-fix, `dart test
  test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart`
  → `00:13 +0 -6: Some tests failed.`):
  - B1: `Expected: contains 'zfa tdd migrate-paths --feature
    .specify/bugs/1573-sample-bug'` — actual fix line
    `zfa tdd migrate-paths 1573-sample-bug` (positional, no flag, no
    path reference)
  - B2: `Expected: contains 'migrated=1'` — actual
    `migrate-paths: migrated=0 refused=0 missing=0
    feature=.specify/bugs/1573-sample-bug` (bug directory never examined)
  - B3: same `migrated=0` with the pin active
  - B4: `Actual: <0>` (exit 0) with output
    `rewriting the recorded form for B1 in 1573-bystander-feature` — the
    silently-discarded slug swept the bystander's registry, the exact
    reported collateral damage
  - B5: actual output `no feature registry found under specs` — the sweep
    cannot see `.specify/bugs/`
  - B6: drift line actual
    `A1: the recorded test path is machine-absolute
    (test/tdd/1573-sample-bug/a1_test.dart)` — the normalized view; the
    raw recorded `/tmp/.../test/tdd/1573-sample-bug/a1_test.dart` never
    appears
- green:
  - fix (see `../fix.md` for the full change list): doctor + proof-chain
    prescription strings → `--feature` form with the canonical reference
    (`resolved.ref` for the doctor's 2b/2c/2e branches); migrate-paths
    `_run()` rejects positional arguments via `usageException`;
    `_scanRegistries` routes `--feature` through
    `TddFeaturePaths.resolveWithPin` with a plain-slug `.specify/bugs/<slug>`
    fallback and sweeps both `specs/` and `.specify/bugs/`; the 2e drift
    line prints the raw recorded value
  - pinned assertions updated where they encoded the broken string shape
    (bug #1397 file ×3, bug #874 file ×3 + its doc comment); no other
    assertion touched
  - post-fix: `00:04 +38: All tests passed.` across the 1573, 1397, 912
    package-URI, gen-namespacing-827, 874 and 969 suites; 840 recovery,
    `test/core/proof/`, artifact-registry suites green; live CLI
    verification: prescription exit 0 with
    `migrated=5 ... feature=.specify/bugs/cycle-log-phantom-sections`
    (dry-run, nothing written), positional rejection raw exit 2
- refactor: none required — the implementation landed directly in the
  prescribed seams (prescription strings, `_scanRegistries`, `_run()`
  arg validation); no behavior-preserving reshape needed

## Verification

- `/speckit.tdd.verify` audit: `tdd/verification.md` (front-matter
  tallies the full fast-tier chunked run, the analyze result and the
  format gate on this machine)
