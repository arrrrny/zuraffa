# Bug Issue: [BUG] zfa tdd gen: registry-owns-missing-file is an unresolvable ownership conflict — the remedy is circular

- **Slug**: 1495-registry-owns-missing-file-recovery
- **Fetched**: 2026-09-13
- **Issue**: 1495
- **URL**: https://github.com/arrrrny/zuraffa/issues/1495
- **State**: open
- **Severity**: high (recovery dead-end; loop-bricking)
- **Author**: arrrrny
- **Labels**: bug, tdd
- **Related**: #840 (`--adopt` origin, opposite drift direction), #1429 (entity-removal verb), #683 (staleness contract)

## Body

`zfa tdd gen` refuses when the registry records a test/subject file that is
missing from disk. The refusal's remedy is circular: it names
`zfa tdd gen <behavior-id>` — the exact command that just refused. No flag,
command, or documented procedure resolves this drift direction.
`--adopt` (bug #840) only covers the OPPOSITE direction: files on disk that
the registry does not own.

## Steps to Reproduce

```bash
# after a normal `zfa tdd gen U16` for feature 001-todo-app
rm test/tdd/001-todo-app/u16_test.dart lib/tdd/001-todo-app/u16_subject.dart
zfa tdd gen U16
```

Observed:

```
zfa tdd gen: ownership conflict — OwnershipConflict: the registry records
test file "test/tdd/001-todo-app/u16_test.dart", but it is missing from
disk. Refusing to overwrite non-owned content. Run `zfa tdd gen U16` after
resolving the conflict.
```

Re-running `zfa tdd gen U16` reproduces the identical refusal. The registry
record persists; the files stay gone; the loop is bricked for that behavior.

## Expected Behavior

1. `zfa tdd gen <id> --repair` drops the stale record and regenerates the
   pair — audit-logged, same discipline as `--adopt`.
2. The refusal names a command that RESOLVES the conflict, not the command
   that refused.
3. `zfa tdd doctor <feature> --repair` garbage-collects every registry
   record whose files are gone (surgical — no full reset).
4. Owned-and-absent has nothing to clobber; regenerating is safe once the
   operator explicitly opts in.

## Actual Behavior

The owned-and-missing direction is treated as an unresolvable conflict:

- `ArtifactRegistry.preflight` throws `OwnershipConflict` ("the registry
  records ... but it is missing from disk").
- `gen` refuses with verdict `refused`; the remedy text names `gen` itself.
- `--adopt` refuses too: "a registry record for ... already exists —
  nothing unowned to adopt".
- `doctor` prescribes `zfa tdd reset <feature>` — a full wipe of the
  feature's records AND owned artifacts, far heavier than the surgical
  drop of the stale record the state calls for.

## Hard Constraints

- Fix ONLY the ownership-conflict handling and remedy text. The ownership
  contract (FR-008 preflight refusal), `--adopt` logic, and the state
  machine are unchanged.
- `--adopt` must keep working for its existing drift direction.
- `dart analyze` with no new warnings.

## Environment

- zuraffa 6.2.2 (zfa CLI), Dart ^3.11.
