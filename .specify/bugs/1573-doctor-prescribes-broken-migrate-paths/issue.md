# Bug Issue: TDD doctor prescribes nonexistent command form — migrate-paths silently discards slug + cannot reach bug directories

- **Slug**: 1573-doctor-prescribes-broken-migrate-paths
- **Fetched**: 2026-09-13
- **Issue**: 1573
- **URL**: https://github.com/arrrrny/zuraffa/issues/1573
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd doctor` on a bug feature prescribes a command form that
`zfa tdd migrate-paths` does not accept, and even the accepted form cannot
reach the bug directory the diagnosis came from.

### Repro

On the shipped fixture `.specify/bugs/cycle-log-phantom-sections` (relocated
registry — machine-absolute recorded paths, artifacts present at the same
project-relative locations):

```
zfa tdd doctor .specify/bugs/cycle-log-phantom-sections
#   --> fix: zfa tdd migrate-paths cycle-log-phantom-sections

zfa tdd migrate-paths cycle-log-phantom-sections --dry-run
# migrate-paths: migrated=5 refused=0 missing=0 feature=all
# Swept EVERY registry in the project — a DIFFERENT feature rewritten.

zfa tdd migrate-paths --feature cycle-log-phantom-sections --dry-run
# migrate-paths: migrated=0 refused=0 missing=0 feature=cycle-log-phantom-sections
# migrated=0 — the bug directory was never examined.
```

### Expected

1. The doctor's `--> fix:` line is an executable command: it must use the
   flag form migrate-paths declares —
   `zfa tdd migrate-paths --feature <ref>` — with the canonical feature
   reference (`resolved.ref`, issue #1471), which for a bug feature is
   `.specify/bugs/<slug>`.
2. `zfa tdd migrate-paths --feature <ref>` reaches
   `.specify/bugs/<slug>/tdd/artifacts.json` (the bug extension's store)
   the same way it reaches `specs/<feature>/tdd/artifacts.json`; the
   no-flag sweep covers both roots too.
3. An unrecognized positional argument is rejected loudly (usage error
   naming the argument and pointing at `--feature`) — never silently
   discarded into a whole-project sweep.
4. The path-form drift line prints the RAW recorded value the migration
   will rewrite, not a display-normalized re-rendering.
5. A test actually EXECUTES the prescribed command and asserts
   `migrated > 0`, so prescription/command drift cannot pass CI again.

### Context

The three defects compose into one user-visible break: the prescription
(names a positional the command ignores) + the silent discard (falls back
to the sweep-all no-flag behavior) + the unreachable store (bug
directories are invisible to `_scanRegistries`). Related: #1397 introduced
the path-form migrate prescription, #874 the cross-feature one, #1471 the
canonical reference convention the adopt prescription already follows.
