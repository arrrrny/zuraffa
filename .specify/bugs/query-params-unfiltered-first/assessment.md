# Bug Assessment: QueryParamsExtension.query answers unfiltered queries with `first`

- **Slug**: query-params-unfiltered-first
- **Created**: 2026-10-25
- **Source**: https://github.com/arrrrny/zuraffa/issues/2018 (allowlisted: github.com)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Issue #2018, "QueryParamsExtension.query: raw StateError on an empty iterable and
an arbitrary element when filter is null".

> `QueryParamsExtension.query` (`lib/src/core/params/query_params.dart:33-38`) uses
> bare `first` semantics, so it:
> 1. throws a **raw `StateError`** (`Bad state: No element`) instead of a typed
>    not-found when the iterable is empty and the filter is null, and
> 2. returns an **arbitrary unrelated element** when the iterable is non-empty and
>    the filter is null — which silently mis-answers an id-scoped lookup.

Observed in production (`arrrrny/zik_zak`, fresh install on the iOS simulator):

```
flutter: 🔴 HivePromptableEventDataSource: Error occurred: StateFailure: No element
flutter:   Stack: #0      Iterable.first (dart:core/iterable.dart:663:7)
#2      QueryParamsExtension.query (package:zuraffa/src/core/params/query_params.dart:35:14)
#3      HivePromptableEventDataSource.get (...hive_promptable_event_datasource.dart:33:26)
```

Downstream product report: `arrrrny/zik_zak#384`.

## Symptom

`Iterable.query(QueryParams(params: {...}))` (no filter) either throws a raw
`StateError` on an empty iterable or returns whatever element happens to be first
in a non-empty one. Expected: a typed not-found when nothing matches, and never an
element that does not answer the query.

## Reproduction

1. `<String>[].query(QueryParams<String>(params: {'id': 'walkthrough_reminder_A'}))`
   → `Bad state: No element` (`StateError`).
2. `['walkthrough_reminder_A'].query(QueryParams<String>(params: {'id': 'walkthrough_reminder_B'}))`
   → `'walkthrough_reminder_A'` (wrong element, silently).
3. Wrapped in `FailureHandler.handleError`, case 1 classifies as `StateFailure` and
   `logAndHandleError` emits `severe` plus an `EXCEPTION CAUGHT` block for an
   expected "not created yet" probe.

## Suspected Code Paths

- `lib/src/core/params/query_params.dart:30-38` — `QueryParamsExtension.query`;
  the `if (params?.filter == null) return first;` branch is the defect. Both the
  unfiltered fallback and the filtered `.first` can raise a raw `StateError`.
- `lib/src/core/params/params.dart:7-11` — `$$Params.params` is documented as
  "Optional additional parameters", yet the generated datasources use it as the
  id lookup key, so the map must be matched against the entity rather than
  ignored.
- `lib/src/core/failure_handler.dart:66-68` — `StateError` → `stateFailure`, the
  path that turns an expected miss into a severe-level log.
- `lib/src/core/failure.dart:380-422` — `NotFoundFailure` (a first-class
  `AppFailure`) is the typed not-found consumers can catch quietly; `AppFailure.from`
  returns it unchanged, so `handleError` preserves the type.
- `lib/src/plugins/datasource/builders/local_generator_impl.dart:95-105` and
  `lib/src/plugins/sqlite/builders/sqlite_datasource_builder.dart:167,423` —
  generated `get()`/`watch()` forward `QueryParams` straight into
  `(values|_selectAll()).query(params)`, so every generated datasource inherits
  the defect.
- `examples/notes_package/lib/src/data/datasources/note/note_mock_datasource.dart:21-26`
  and `examples/reference_package_app/bin/app.dart:25-28` — the framework's own
  reference consumer resolves a note with `QueryParams<Note>(params: {'id': 'id 1'})`,
  which only works today because the requested note happens to be first.

## Root Cause Hypothesis

Confidence: high. `query` treats "no filter" as "any element" (`first`) instead of
matching the query's params against the entity. Two consequences share the one
line: an empty iterable surfaces the raw `Iterable.first` `StateError`, and a
non-empty one returns an unrelated element — a data-integrity trap for id-scoped
lookups (the caller may then read and write entity A while asking for entity B).

## Proposed Remediation

**Preferred**: answer a params-only query by *matching*, and make every
no-match path a typed `NotFoundFailure` (the issue's second option, which the
generated consumers actually depend on).

- `filter != null`: scan with `filter.matches`, return the first match; when there
  is none, throw `NotFoundFailure` (typed, catchable, quiet) instead of `.first`.
- `filter == null` with a non-empty `params` map: compare each entity's JSON view
  against the params and return the matching entity. Zorphy entities generate
  `toJsonLean()` as an instance method (their `toJson()` is an extension, so it is
  not reachable by dynamic dispatch); a `toJson()` fallback covers hand-written
  entities. When nothing matches — or the element type exposes no JSON view at
  all — throw `NotFoundFailure` rather than returning an arbitrary element.
- `filter == null` and no params (`query(null)` / `QueryParams()`): preserve the
  documented first-element behaviour the existing test asserts, but throw
  `NotFoundFailure` on an empty iterable instead of the raw `StateError`.
- Update the doc comment to state the throw and the params-matching rule.

**Alternatives**:
- Fail closed on every params-only query (the issue's first option) — rejected:
  the generated mock datasource (`NoteMockDataSource.get` →
  `NoteMockData.notes.query(params)`) and the spec-025 reference app
  (`QueryParams<Note>(params: {'id': 'id 1'})`, agent tool schema
  `{"id": "id 1"}`) both use params as the id lookup, so failing closed would
  break that documented flow instead of fixing it.
- Return `T?` from a new `queryOrNull` — additive API, but leaves the existing
  trap in place and callers must migrate.

**Files likely to change**:
- `lib/src/core/params/query_params.dart`
- `test/core/params_wrappers_test.dart`

**Tests to add or update**:
- empty iterable + `QueryParams(params: {'id': ...})`, null filter → expects
  `NotFoundFailure` (not `StateError`).
- non-empty iterable + `QueryParams(params: {'id': 'other'})`, null filter →
  expects `NotFoundFailure` and asserts no element is returned.
- non-empty iterable + params naming an existing entity → returns that entity,
  not the first one.
- filtered query with no match → `NotFoundFailure`.
- existing `query(null)` first-element case stays green.

## Risks & Considerations

- Behaviour change for callers that passed `params` only: the query now returns
  the entity whose fields match instead of the first element, and raises
  `NotFoundFailure` on a miss. The old behaviour was the reported data-integrity
  bug, so this is the intended correction.
- Params matching reads the entity's JSON view (`toJsonLean()`, falling back to an
  instance-level `toJson()`); an element type that exposes neither fails closed
  with `NotFoundFailure`, never an arbitrary element. Values are compared with
  `==` against the JSON view, so non-JSON scalars (e.g. a `DateTime` queried as a
  `DateTime`) will not match its serialized form.
- `NotFoundFailure` is already exported from `package:zuraffa/zuraffa.dart`, so no
  new public surface is introduced.
- `logAndHandleError` still logs every failure at `severe`; changing that is a
  separate concern (out of scope for this issue).

## Open Questions

- None. The issue states the acceptance criteria precisely.
