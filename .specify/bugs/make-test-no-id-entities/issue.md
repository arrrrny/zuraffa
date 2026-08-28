# Bug Issue: zfa make --test still fails for no-id entities

- **Slug**: make-test-no-id-entities
- **Fetched**: 2026-08-27T13:15:21Z
- **Issue**: 514
- **URL**: https://github.com/arrrrny/zuraffa/issues/514
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

#510 ("gate no-id loud failure on id-dependent plugins", Closes #508) claims to make `zfa make <Entity> --test` work for no-id entities. It does not: `zfa make AuthRequest --test` still errors with "the entity has no id field." The gate was correctly moved to fire only when an id-dependent plugin is active, but `zfa make --test` itself resolves to the plan `[usecase, test]`, and `usecase` is id-dependent — so the gate still fires.

## Reproduction

In `apps/zikzak_demo`:

```bash
zfa make AuthRequest --methods=get,update,toggle --test --dry-run
```

`AuthRequest` is a legitimate no-id entity (auth request / value object, no `id` field). `zfa make AuthRequest --test --plan` resolves to `Requested: usecase, test / Resolved: usecase, test`.

## Expected

Per #510, id-neutral test regeneration should proceed for no-id entities, resolving a representative real field as the query key (`EntityFieldResolver.resolveRepresentativeField`). The 3 usecase test files (get/update/toggle) should regenerate mocktail-free.

## Actual

```
❌ Cannot generate architecture for "AuthRequest": the entity has no id field.
```

Exit code 1. No files written (dry-run).

## Root cause

`lib/src/commands/make_command.dart`:

1. `zfa make <Entity> --test` → `manager.resolvePlan(...)` resolves to `[usecase, test]`. The `--test` flag **implicitly includes the `usecase` plugin** — it is not test-only.
2. The #307 no-id gate (lines 472–520) fires when `hasIdDependentPlugin = activePlugins.any((p) => _idDependentPlugins.contains(p.id))` is `true`. `usecase` is in `_idDependentPlugins` (lines 58–73) and is legitimately id-dependent for a no-id entity, so the gate fires — even though only the id-neutral test files were wanted (they import the already-generated usecase).
3. #510 moved the failure behind `hasIdDependentPlugin` correctly, but did not account for `--test` dragging in the id-dependent `usecase` plugin. The doc comment (lines 49–51) calls `test` id-neutral, but the actual blocker is `usecase`.
4. Secondary inconsistency (not the blocker): line 42 still lists `'test'` inside `_idDependentPlugins` with a comment cut off mid-sentence (`// entity tests reference the usecases value objects don't get`), contradicting the doc comment.

## Suggested fix

For no-id entities, when the resolved plan's id-dependent plugins are only present because `--test`/`--mock` implied them (and the generated usecase already exists), **drop those id-dependent plugins during regeneration** — mirroring the existing value-object handling at lines 434–450, which drops root plugins for value objects. This makes `zfa make --test` regenerate only the id-neutral test files for no-id entities, fulfilling #510's stated intent.

Alternatives:
- Decouple `--test` from implicit `usecase` generation so `zfa make --test` is truly test-only.
- Or document that no-id test regeneration requires `zfa make <Entity> --test --no-usecase` (but this contradicts #510's claim that `--test` alone works).

Also clean up the `'test'` entry + dangling comment at lines 42 / 49–51.

## Blast radius

Blocks the bulk mocktail-removal regeneration of `apps/zikzak_demo` (~250 test files; multiple no-id entities: AuthRequest, Barcode, …) and `apps/forklift`. Per AGENTS.md STOP-ON-ROADBLOCK, these must come from `zfa` and cannot be hand-edited, so the migration is blocked at the generator level.

## Comments

None.
