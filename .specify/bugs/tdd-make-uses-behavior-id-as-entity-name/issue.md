# Bug Issue: [BUG] zfa tdd make: uses behavior ID as entity name for zfa make

- **Slug**: tdd-make-uses-behavior-id-as-entity-name
- **Fetched**: 2026-09-01
- **Issue**: 696
- **URL**: https://github.com/arrrrny/zuraffa/issues/696
- **State**: open
- **Severity**: unknown
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd make` for unit behaviors tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name. Behavior IDs like `u5`, `u6` are NOT entity names, so `zfa make` fails with `no entity source file was found`.

## Steps to Reproduce

1. `zfa setup`, `zfa tdd init`, copy spec, `zfa tdd plan`
2. `zfa tdd gen U5 --feature=001-app-bootstrap`
3. `zfa tdd verify-red U5 --feature=001-app-bootstrap`
4. `zfa tdd make U5 --feature=001-app-bootstrap` → exit 1: `zfa make u5` → `no entity source file was found`

## Expected Behavior

`zfa tdd make` for unit behaviors should either: (1) not attempt entity generation for behavior IDs that don't map to entities, (2) derive the actual entity name from the behavior's trace (FR-xxx), or (3) use `--no-entity` flag.

## Workaround

Manually create the entity first, or skip `zfa tdd make` for unit behaviors that don't have a corresponding entity.