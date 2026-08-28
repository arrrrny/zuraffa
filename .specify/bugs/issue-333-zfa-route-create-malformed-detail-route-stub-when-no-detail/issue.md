# Bug Issue: zfa route create: malformed detail-route stub when no detail_view (108 broken files, stray comma + mangled pathParameters['id'])

- **Slug**: issue-333-zfa-route-create-malformed-detail-route-stub-when-no-detail
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 333
- **URL**: https://github.com/arrrrny/zuraffa/issues/333
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: none

## Body

## Context

Smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` with ONLY zfa commands). After #328's fix (#331 — "probe detail_view on disk + accept entity named-param"), I re-ran `zfa route create <Entity> --methods=get,getList` for all 53 entities. Result: **`zfa build` fails with exit code 1** — the generated routing layer has broken syntax in **108 route files**.

## What I ran

```bash
zfa view create <Entity> ...    # (views were generated earlier via zfa make --with=vpc)
zfa route create <Entity> --methods=get,getList --force   # ×53
zfa build
```

## Expected

Generated route files compile.

## Actual

`zfa build` fails: `E json_serializable on lib/src/routing/error_log_routes.dart: 25:5: Expected an identifier.` (same for dynamic_form, extracted_invoice, feedback, form_option, form_submission, ...). Every route file contains a **malformed detail-route stub**:

```dart
// error_log_routes.dart (generated), lines ~22-29:
    GoRoute(
      path: ErrorLogRoutes.errorLogList,
      name: 'error_log_list',
      builder: (context, state) {
        return ErrorLogView(errorLog: (state.extra as ErrorLog?));
      },
    ),
    ,                       // <-- stray comma + blank line (syntax error)

GoRoute(path: ErrorLogRoutes.errorLogDetail, name: 'error_log_detail', builder: (context, state, ) { return  ErrorLogView(id: state.pathParameters  [
'id'
]!, errorLog: (state.extra as ErrorLog?), ); } , ),
];
```

Two concrete defects:
1. **Stray `,` / blank line** after the list route — invalid Dart.
2. **Detail route collapsed onto one line with mangled syntax** — `state.pathParameters  [ 'id' ]!` (space-split array literal) instead of `state.pathParameters['id']!`, plus `(context, state, )` trailing comma in the closure params.

**108 route files affected** (verified via grep for `pathParameters  [`), and **0 detail views exist** (`ls lib/src/presentation/pages/*/detail_view.dart` → 0).

## Root cause

#331 changed the route generator to "probe detail_view on disk" and only reference `EntityDetailView` when the file exists — but when the probe finds **no** detail view, the generator still emits a **detail route stub** (with the `id` param and the entity param) instead of omitting the detail route entirely. That stub path is emitted through a different (broken) code path — producing the stray comma + collapsed one-line GoRoute with the mangled `pathParameters ['id']` access. `zfa view` never generates detail views (only the single view), so the stub is always emitted in the broken form.

## Suggested fix

1. When the detail-view probe finds **no** `<entity>_detail_view.dart`, do NOT emit a detail route at all — the route file should contain only the list route (or however many views actually exist).
2. The stub-emission code path itself is broken (stray comma, collapsed formatting, `pathParameters  [ 'id' ]!`): fix the emitter to produce valid `state.pathParameters['id']!` and proper multi-line structure — or delete the dead stub path entirely.
3. Consider: `zfa view create` with `getList` should generate a list + detail view pair so routes have real targets (the reference app has both `<x>_view.dart` and `<x>_detail_view.dart`).

## Impact

Blocks the entire routing layer again — #331 was necessary but insufficient; the no-detail-view path emits uncompilable Dart. 108 of 53 entities' route files are broken.


## Comments

None.
