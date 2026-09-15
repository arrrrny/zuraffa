# Bug Assessment: MOCK-CREATE --force leaves stale datasource interface when --methods changes

- **Slug**: 1418-mock-force-regen-interface
- **Created**: 2026-09-16
- **Source**: https://github.com/arrrrny/zuraffa/issues/1418
- **Verdict**: valid — reproduce path is deterministic from generator source structure
- **Severity**: unknown (no severity label on issue)
- **Reporter**: arrrrny (repo owner)

## Symptom Summary

Two coupled defects in the `zfa mock create` output pipeline:

1. **Primary — pair drift on `--force`.** `mock create` writes the datasource
   interface (`<entity>_datasource.dart`) create-if-absent, but always
   regenerates the mock body from the current `--methods` selection. Running
   `mock create E --methods list` then
   `mock create E --methods getList --certify --force` leaves the interface
   declaring `list(NoParams)` while the mock implements `getList(ListQueryParams<E>)`.
   The pair no longer compiles ("Missing concrete implementation") and
   certification dead-ends across repeated `--force` runs.

2. **Secondary — undefined hide names.** Generated imports emit
   `hide <Entity>, <Entity>Patch` unconditionally from the entity name without
   checking whether the target library (`zuraffa.dart`, `mock.dart`) actually
   exports those names. Analyzer reports `undefined_hidden_name` warnings in
   generator-owned files, which fail `zfa build`'s analyze gate during
   `zfa tdd run` refactor passes.

## Impact

- `--force` cannot recover from a methods mismatch — the advertised recovery
  path is broken.
- Analyze gate poisoning: warnings inside generated files block builds and
  refactor passes for conforming projects.

## Scope Guard

- Fix the mock create force path (interface invalidation) and hide emission only.
- Do NOT change certification logic.
- Do NOT change the entity pipeline.

## Acceptance Criteria

1. `--force` regenerates both interface and mock when `--methods` changes.
2. `undefined_hidden_name` warnings eliminated from generated datasource files.
3. Certification passes on a `--force`-regenerated pair with changed methods.
4. No regressions on existing mock creation (non-force path).

## Reproduction Plan (test-level)

- Unit: mock datasource writer invoked with force=true on an existing
  interface must overwrite the interface content to match current methods.
- Unit: hide-list builder must filter candidate hide names against the target
  library's export surface.
- Regression: non-force create on absent interface still writes both files.
