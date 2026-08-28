# Fix Report: issue #410 — `zfa di create` referencing non-existent `<entity>_usecase.dart` / `EntityUseCase`

- **Slug**: issue-410-zfa-di-create-generates-usecase-di-referencing-non-existent
- **Issue**: https://github.com/arrrrny/zuraffa/issues/410
- **Status**: ALREADY FIXED IN-TREE (no source change required)
- **Investigated**: 2026-08-28
- **Regression test**: `test/regression/issue_410_di_create_usecase_di_test.dart` (5/5 passing)

## Summary

The reported defect is no longer reproducible on `master`. `zfa di create <Entity>`
now emits per-method usecase DI files (`get_<entity>_usecase_di.dart`,
`update_<entity>_usecase_di.dart`, …) that import the real per-method usecase
files and reference the real `Get<Entity>UseCase` / `Update<Entity>UseCase` /
`Create<Entity>UseCase` / `Delete<Entity>UseCase` classes that
`zfa usecase create <Entity>` generates. It does **not** emit the broken unified
`<entity>_usecase_di.dart` referencing a non-existent `<Entity>UseCase` type.

## Root cause (as described in the issue)

`zfa di create <Entity>` was building its `GeneratorConfig` with no `methods`.
With empty methods, `isEntityBased` evaluated false and the DI dispatcher fell
into `_generateCustomUseCaseDI`, which emitted:
- `my_entity_usecase_di.dart`
- importing `my_entity_usecase.dart` (never generated)
- referencing `MyEntityUseCase` (never generated)

That produced ~100 `uri_does_not_exist` / `non_type_as_type_argument` /
`undefined_function` errors under `dart analyze`.

## Fix already in tree

1. `lib/src/plugins/di/capabilities/create_di_capability.dart`
   - Introduced in commit `58ae6628` ("Development (#432)").
   - `_generateFiles` now derives `isCustomUseCase` (present when
     `repo`/`service`/`usecases`/`domain`/`noEntity` is set) and defaults
     `effectiveMethods` to `['get', 'update']` for the plain entity case —
     matching `zfa usecase create <Entity>`. This routes the DI dispatcher to
     `_generateEntityUseCaseDIFiles`.

2. `lib/src/plugins/di/di_plugin.dart`
   - The `isEntityBased` → `_generateEntityUseCaseDIFiles` routing was
     introduced in commit `1bd2097e` ("fix(zfa make): always generate data repo
     impl + wire per-method DI for entity presets (#284) (#287)").
   - `_generateEntityUseCaseDIFiles` iterates `config.methods` and, for each
     valid method, calls `_getUseCaseInfo` to resolve the exact per-method
     usecase class (`Get<Entity>UseCase`, `Update<Entity>UseCase`, …) and writes
     a matching `*_usecase_di.dart` importing the real usecase file.

The unsupported custom-usecase path (`_generateCustomUseCaseDI`, emitting the
unified `<name>_usecase_di.dart`) is intentionally preserved for genuine
hand-written single usecases via `--no-entity` / `--repo` / `--service` /
`--domain` / `--usecases` — that path was never the source of the bug.

## Verification

```
$ dart test --preset=regression test/regression/issue_410_di_create_usecase_di_test.dart
00:00 +5: All tests passed!
```

The regression suite pins:
- entity default emits per-method DI (get/update) referencing real classes;
- the broken unified `my_entity_usecase_di.dart` is NOT generated;
- every DI usecase import resolves to a file `zfa usecase create` actually emits;
- explicit `--methods` overrides the default;
- the custom-usecase paths (`--no-entity`, `--repo`) still emit the unified DI.

## Action taken

No source code changes were needed — the fix is already merged. This file
documents the resolution and the regression test that guards it.
