# Bug Issue: [BUG] zfa tdd make: uses behavior ID as entity name for zfa make

- **Slug**: tdd-make-uses-behavior-id
- **Fetched**: 2026-09-01
- **Issue**: 696
- **URL**: https://github.com/arrrrny/zuraffa/issues/696
- **State**: open
- **Severity**: unknown
- **Author**: (unknown — fetched via gh JSON)
- **Labels**: bug

## Body

`zfa tdd make` for unit behaviors tries to run `zfa make <behaviorId>` (lowercased), treating the behavior ID as an entity name. Behavior IDs like `u5`, `u6` etc. are NOT entity names, so `zfa make` fails with `no entity source file was found`.

## Steps to Reproduce

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd gen U5 --feature=001-app-bootstrap`
5. `zfa tdd verify-red U5 --feature=001-app-bootstrap`
6. `zfa tdd make U5 --feature=001-app-bootstrap`
   → **exit 1**: `zfa make u5` → `Cannot run zfa make for u5: no entity source file was found.`

## Expected Behavior

`zfa tdd make` for unit behaviors should either:
1. Not attempt entity generation for behavior IDs that don't map to entities
2. Derive the actual entity name from the behavior's trace (FR-xxx)
3. Use `--no-entity` flag

## Actual Behavior

`zfa tdd make` lowercases the behavior ID (`U5` → `u5`) and passes it to `zfa make`, which fails.

## Workaround

Manually create the entity first, or skip `zfa tdd make` for unit behaviors that don't have a corresponding entity.

## Environment

- zfa version: current
- Flutter version: 3.41.0+
- Dart version: 3.11.0+
- Platform: macOS

## Comments

None.
