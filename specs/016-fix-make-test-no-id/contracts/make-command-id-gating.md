# Contract: MakeCommand id-gating (issue #508)

**Feature**: 016-fix-make-test-no-id | **Date**: 2026-08-27

Behavioural contract for `zfa make`'s entity-resolution step. All clauses are testable from the CLI surface (exit code + stdout + files on disk) or via `CliRunner.runCapturing`.

## C1. Id-less entity + id-neutral plugins only

**Given** an entity with no id-like field, no `autoId`, and no value-object annotation, **and** the active plugin set intersecting the id-dependent set emptily (e.g. `--test` alone, `--test --mock`):

- `zfa make <E> ...` MUST exit 0 and run the requested plugins.
- `MakeCommandException('Cannot generate architecture for "<E>": the entity has no id field.')` MUST NOT be thrown.
- `PluginContext.data['query-field']` MUST equal the name of a real field of `<E>` (see C3), and `data['query-field-type']` its non-nullable type — unless the user passed `--query-field`, in which case the user's value MUST be preserved verbatim.

## C2. Id-less entity + any id-dependent plugin

**Given** the same entity, **and** at least one active plugin in the id-dependent set (repository, datasource, usecase, controller, presenter, service, provider, route, view, gql, graphql, sqlite, api, sync):

- `zfa make <E> ...` MUST print the exact #307 diagnostic (message + the three remediation hints: add an id field / recreate with `--auto-id` / mark as value object) and exit 1 via `MakeCommandException`.
- No files may be written.
- `--id-field`/`--id-field-type` flags MUST NOT bypass this (unchanged #321 contract).

## C3. Representative field rule (used by C1)

For entity source fields in declaration order:

1. first field with non-nullable type `String`;
2. else first field with non-nullable type `int`;
3. else first field with nullable type `String?`/`int?`;
4. else first field with type `double`, `num`, `bool`, or `DateTime`;
5. else no query field is set (plugins keep their defaults; regeneration still proceeds).

A field whose type is a custom identifier (enums included) MUST NOT be selected at any step. A synthetic `id` MUST NOT be invented.

## C4. Id-bearing entities (regression guard)

For entities with a literal `id`, an `*Id`-suffixed field, or `autoId: true`: behaviour MUST be identical to master before this change (resolution message, populated `id-field`/`query-field`, all suites green). `PriceAlert` is the canonical control.

## C5. Value objects (regression guard)

`@ZValueObject` / `kind: ZorphyKind.valueObject`: unchanged — root plugins (including `test`) are dropped with the notice; no loud failure, no query-field invention.

## C6. Id-dependent set declaration

The set MUST be declared exactly once as a named `static const Set<String>` on `MakeCommand` (single greppable symbol), and the gate MUST be expressed as an intersection with the active plugin ids — no inline list at the call site.

## C7. Regression tests (repo-level)

The zuraffa test suite MUST contain tests proving:

- C1 green path: `--test`-only on an id-less entity succeeds (exit 0 / no `MakeCommandException`), using the `runCapturing` pattern so the isolate survives;
- C2 red path: an id-dependent plugin on the same entity still throws with the unchanged message;
- C3: representative-field selection prefers `String`, skips enum-typed fields, and honours user-passed `--query-field`;
- existing #307/#321 tests remain untouched and green.
