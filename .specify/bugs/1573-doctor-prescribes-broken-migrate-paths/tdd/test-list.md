# Test List: bug #1573 — doctor prescribes a broken migrate-paths command

Traces: GitHub issue #1573 · assessment in this directory · hard
constraints: only the prescription strings, the migrate-paths registry
scope, and migrate-paths argument handling may change; path-form
normalization, doctor detection logic and the TDD state machine are
untouched; `dart analyze` must stay clean.

- feature: 1573-doctor-prescribes-broken-migrate-paths
- source: issue.md (Expected section) + assessment.md Symptom/Reproduction
- suite tier: fast (`dart test test/plugins/tdd/commands/bug_1573_doctor_prescribes_broken_migrate_paths_test.dart`)

## Behaviors

| id | behavior | serves | test | state |
| -- | -------- | ------ | ---- | ----- |
| B1 | `zfa tdd doctor .specify/bugs/<slug>` on a relocated bug registry prescribes `zfa tdd migrate-paths --feature .specify/bugs/<slug>` — the flag form, with the canonical reference that reaches the bug directory (verdict stays `drift`/`migrate`) | issue Expected 1 | same file → `Bug #1573 — the prescription is executable doctor on a bug feature prescribes migrate-paths --feature with the canonical bug reference` | green |
| B2 | Executing the prescribed command heals the diagnosed bug registry: `migrated=1`, the registry's records are rewritten to the portable project-relative POSIX form, and a doctor re-run returns `healthy` | issue Expected 1+2; the CI-proof the old suite lacked (executes the prescription) | same file → `the prescribed command heals the bug registry (migrated > 0)` | green |
| B3 | A plain bug slug with the bug extension pin active (`.specify/feature.json` → `feature_directory: .specify/bugs/<slug>`) resolves to the bug registry and migrates it | issue Expected 2 (pin path of the resolver contract) | same file → `a plain bug slug resolves through the bug extension pin` | green |
| B4 | An unrecognized positional argument exits `ExitProtocol.usage` (2) with a message naming the argument and pointing at `--feature`; a bystander form-drift registry under `specs/` stays byte-identical (the silent whole-project sweep is dead) | issue Expected 3 | same file → `an unrecognized positional is a usage error, never a whole-project sweep` | green |
| B5 | The no-flag sweep migrates a bug-directory registry (`migrated=1`, portable rewrite) — `.specify/bugs/*/tdd/artifacts.json` is first-class registry coverage | issue Expected 2 | same file → `migrate-paths with no flag migrates a bug-directory registry` | green |
| B6 | The 2e path-form drift line prints the RAW recorded machine-absolute string verbatim, not the display-normalized re-rendering | issue Expected 4 | same file → `the path-form drift prints the recorded absolute string, not a normalized re-rendering` | green |

## Regression surface guarded by pre-existing tests

- The four doctor prescription branches and their verdicts: bug #874
  foreign-owned suite (3 pinned `--> fix:` assertions updated to the flag
  form; the two-owners all-features prescription and `isNot` assertions
  unchanged), bug #840 recovery-commands suite, bug #912 import-drift
  prescription group.
- migrate-paths semantics: bug #1397 form-rewrite group (fail-honest,
  idempotency, dry-run, relocated repair), bug #912 defect 4 package-URI
  group (move/refuse/self-check), gen-namespacing #827 group — all
  re-run green; the sweep tests in 912 (no-flag invocations) prove the
  widened sweep did not change specs/ behavior.
- Proof chain: `test/core/proof/` re-run green (the checker's only change
  is the fix-string payload).
