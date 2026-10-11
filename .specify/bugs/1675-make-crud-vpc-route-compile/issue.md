# Bug Issue: `zfa make <E> --preset=crud --vpc --route` emits non-compiling Dart

- **Slug**: 1675-make-crud-vpc-route-compile
- **Fetched**: 2026-09-18T00:00:00+00:00
- **Issue**: 1675
- **URL**: https://github.com/arrrrny/zuraffa/issues/1675
- **State**: open
- **Severity**: high
- **Author**: arrrrny
- **Labels**: bug

## Body

### Summary

`zfa make Todo --preset=crud --vpc --state --route --di --mock --use-mock --test --methods=get,getList,create,update,delete` emits Dart that does not compile: the generated repository calls a `CachePolicy` method that does not exist in the published package, and the generated route passes an untyped `String` path parameter into a view whose `id` field is typed from the entity (`id:int` → `int?`). `zfa build`'s analyze gate then fails the tree while mislabeling the freshly generated files as hand-authored user code.

### Repro

```bash
zfa setup todo_app --platforms=macos
zfa entity create -n Todo --field id:int --field title:String --field done:bool
zfa make Todo --preset=crud --vpc --state --route --di --mock --use-mock --test --methods=get,getList,create,update,delete
zfa build
```

`zfa build` fails at the analyze gate with 3 errors:

1. `lib/src/data/repositories/data_todo_repository.dart:82` —
   `The method 'markStale' isn't defined for the type 'CachePolicy'`.
   The repository template emits `await _cachePolicy.markStale('todo_cache');`
   after `delete`, but the published `CachePolicy` API (zuraffa 6.1.0)
   declares only `isValid` / `markFresh` / `invalidate` / `clear`.
   **Template↔package skew.**
2. `lib/src/routing/todo_routes.dart:34` and `:51` —
   `The argument type 'String' can't be assigned to the parameter type 'int?'`.
   The route builder passes `id: state.pathParameters['id']!` (always
   String) straight into the generated view whose `id` field is typed from
   the entity field (`id:int` → `int?`). **The route generator never parses
   non-String path parameters** on the `zfa make` plugin path.
3. `zfa build`'s analyze-gate message labels the offenders
   "hand-authored offending (not generator output)" — wrong for files
   `zfa make` just wrote.

### Expected

The full repro compiles through `zfa build` with zero hand-patching: the
repository emits cache-API calls that exist in the resolved package, the
route parses path parameters per the bound field's type (`int.tryParse` /
`int.parse` for int fields), and the analyze gate attributes generator
output to the generator.
