# Bug Issue: zfa make: generates references to non-existent Enums entity

- **Slug**: issue-418-zfa-make-generates-references-to-non-existent-enums-entity
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 418
- **URL**: https://github.com/arrrrny/zuraffa/issues/418
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa make` / `zfa datasource create` generates code referencing an `Enums` entity that doesn't exist and is never created by any entity command.

**Reproduction**:
1. `zfa entity create -n Enums --field "id:String" --field "values:List<String>"` (manual creation required)
2. Without it, generated datasource/use case files have `import '../../../domain/entities/enums/enums.dart'` → `uri_does_not_exist`

**Expected**: Either auto-generate `Enums` when referenced, or don't generate references to non-existent entities.

**Note**: This may be a symptom of the Enums plugin being incomplete.


## Comments

None.
