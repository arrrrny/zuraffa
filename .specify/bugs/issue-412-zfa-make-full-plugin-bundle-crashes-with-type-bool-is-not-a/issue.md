# Bug Issue: zfa make: full plugin bundle crashes with 'type bool is not a subtype of String?' but individual plugins work

- **Slug**: issue-412-zfa-make-full-plugin-bundle-crashes-with-type-bool-is-not-a
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 412
- **URL**: https://github.com/arrrrny/zuraffa/issues/412
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa make <Entity> repository usecase di mock provider service datasource` crashes with `type 'bool' is not a subtype of type 'String?' in type cast`, but individual `zfa <plugin> create <Entity>` commands work fine.

**Reproduction**:
1. `zfa entity create -n TestEntity --field "id:String" --field "name:String"`
2. `zfa make TestEntity repository usecase di mock provider service datasource` → crash
3. `zfa repository create TestEntity` → works
4. `zfa usecase create TestEntity` → works
5. `zfa provider create TestEntity --data` → works
... all individual create commands work

**Root cause**: The `make` command's plugin orchestration has a type-cast bug when combining multiple capabilities.

**Files**: `lib/src/commands/make_command.dart` or the plugin orchestrator.


## Comments

None.
