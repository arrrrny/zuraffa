# 1573-doctor-migrate-paths-fix

- **Spec ID**: 1573-doctor-migrate-paths-fix
- **Created**: 2026-09-13
- **Source**: GitHub issue #1573 (SPEC 1573 — TDD doctor prescribes nonexistent command form — migrate-paths silently discards slug + cannot reach bug directories)
- **Type**: bug fix (P1 — the prescribed recovery path is unwritable-as-given and cannot reach the drifted registry it names)
- **Branch**: feat/1573-doctor-migrate-paths-fix
- **Related**: #1397 (path form mismatch test asserts the positional string), #874 (migrate-paths origin — the cross-feature prescription), #1471 (feature-ref resolution every family command routes through), #1182 (bug-directory shape)

## Problem

`zfa tdd doctor` detects machine-absolute recorded paths and prescribes a
`migrate-paths` invocation in the POSITIONAL form —
`zfa tdd migrate-paths <feature>` — but `migrate-paths` declares no
positional argument: the slug is silently discarded (`argResults.rest` is
never read), and the command then migrates EVERY `specs/` registry instead
of the named one. Worse, even the correct `--feature` form cannot reach the
registry doctor diagnosed: `_scanRegistries` resolves a plain name to
`specs/<name>` only, while a bug feature's registry lives at
`.specify/bugs/<slug>/tdd/artifacts.json` — the doctor resolved the bug
directory through the family resolver (#1471) and prescribed a command that
is structurally unable to open it.

Live reproduction on this repo's own fixture (HEAD 9254ec1d):

```
$ zfa tdd doctor .specify/bugs/cycle-log-phantom-sections
   --> fix: zfa tdd migrate-paths cycle-log-phantom-sections — ...

$ zfa tdd migrate-paths cycle-log-phantom-sections --dry-run
migrate-paths: migrated=92 refused=0 missing=2 feature=all
# slug silently discarded — 92 records across EVERY specs/ feature rewritten

$ zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run
migrate-paths: migrated=0 refused=0 missing=0 feature=cycle-log-phantom-sections
# bug directory never examined
```

Root causes (issue #1573):

1. The prescription uses the positional form
   (`proof_chain_checker.dart:703`, plus the same string shape in
   `doctor_command.dart` (checks 1/2c/2e/2b) and `gen_command.dart`'s two
   foreign-owner verdicts) but the command accepts `--feature`.
2. `migrate-paths` only reads `specs/` (`migrate_paths_command.dart`
   `_scanRegistries`) — bug directories at `.specify/bugs/*/tdd` are
   unreachable, both through the flag and through the no-flag sweep.
3. The existing tests assert only the STRING SHAPE of the prescription
   (#1397: `contains('zfa tdd migrate-paths $feature')`) — no test ever
   executes the prescribed command, so a prescription that migrates
   nothing (or everything) still reads green.
4. Doctor's path-form drift line prints the recorded value NORMALIZED
   (`_displayPath(cwd, p.normalize(record.testPath))` renders a relative
   POSIX path) while claiming the value is machine-absolute — the drift
   line names a form the registry does not carry.

## Goal

One deterministic repair surface: the doctor (and every sibling
prescription site) emits the flag form the command actually parses;
`migrate-paths` reaches the bug-extension registries; unrecognized
positional arguments are rejected loudly instead of silently widening the
migration; the drift line prints the raw recorded value; and a test closes
the loop by EXECUTING the prescribed command and asserting `migrated > 0`.

## Success criteria (measurable)

- **SC-1**: For a machine-absolute-form registry, `zfa tdd doctor <ref>`
  emits `fix: 'zfa tdd migrate-paths --feature $feature'` (both the
  `--> fix:` line and the JSON verdict `fix` key), where `$feature` is the
  resolved feature name. The sibling prescription sites
  (`proof_chain_checker.dart` test-integrity import drift,
  `doctor_command.dart` single-owner foreign-owned / relocated-registry /
  form-drift / import-drift checks, `gen_command.dart` foreign-owner
  verdicts) emit the same flag form; the multi-owner form stays the
  flag-less whole-project invocation.
- **SC-2**: `zfa tdd migrate-paths --feature <ref>` covers
  `.specify/bugs/<slug>/tdd/artifacts.json`: a plain-slug reference whose
  `specs/<slug>` registry does not exist migrates the bug directory's
  registry (conventional `.specify/bugs/<slug>` probe, pin file not
  required); an explicit `.specify/bugs/<slug>` reference resolves
  directly; and the no-flag sweep includes every
  `.specify/bugs/<slug>/tdd/artifacts.json` in addition to `specs/`.
- **SC-3**: `zfa tdd migrate-paths <anything>` (any unrecognized positional
  argument) is rejected loudly: usage error, exit code 2, the message names
  the `--feature` flag form — never a silent whole-project sweep.
- **SC-4**: The closing test executes the command string the doctor
  prescribed (tokenized from the `--> fix:` payload) against a seeded
  machine-absolute fixture and asserts `migrated > 0` — the prescription
  is verified by execution, not by string shape.
- **SC-5**: The doctor path-form drift line prints the RAW recorded value
  (the exact machine-absolute string stored in `artifacts.json`), not the
  normalized relative display form.

## Hard constraints

- Fix ONLY the prescription string, `migrate-paths` scope, and argument
  handling (plus the drift-line rendering and the tests that pin them).
  No migration-mechanics changes: pair-atomicity, ownership refusals,
  fail-honest missing reports, cycle-log rewrites stay byte-identical.
- Must pass `dart analyze` with no new warnings.
- Related suites must stay green: #1397 and #874 assertions updated to the
  flag form (the tests that asserted the buggy string shape).
- One PR, `Closes #1573`.

## Out of scope

- Teaching `migrate-paths` new reference shapes beyond the family resolver
  (no `~` expansion, no globbing).
- Changing the doctor's deterministic check order or verdict taxonomy.
- Reworking `_scanRegistries` dedup semantics (a slug present under BOTH
  `specs/` and `.specify/bugs/` is two registries; both migrate).
