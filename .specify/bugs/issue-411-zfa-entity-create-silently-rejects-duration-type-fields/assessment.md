# Bug Assessment: zfa entity create: silently rejects Duration type fields

- **Slug**: issue-411-zfa-entity-create-silently-rejects-duration-type-fields
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Refined**: 2026-08-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/411
- **Verdict**: valid — confirmed by code inspection
- **Severity**: medium (blocks any entity with a `Duration` field)

## Report (verbatim or summarized)

`zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"` writes no
entity file. Expected: accept `Duration` (emit `Duration? wallClockTimeout`) or
fail with a clear, actionable message.

## Symptom

The command aborts with exit 1 and writes nothing. The abort path is the
"field type(s) could not be resolved" branch, whose message tells the user to
run `zfa entity enum -n Duration ...` — nonsensical for a dart:core type, and
easy to miss/appear silent in tool-driven runs.

## Reproduction

1. `zfa entity create -n StopPolicy --field "wallClockTimeout:Duration"`
2. No file under `lib/src/domain/entities/stop_policy/`.

Pure-unit reproduction (no CLI needed):
`EntityUtils.extractEntityTypes('Duration')` returns `['Duration']`, which makes
`EntityTypeValidator.validate` emit an `UnresolvedTypeError`.

## Suspected Code Paths

- `lib/src/utils/entity_utils.dart:29-49` — `extractEntityTypes` exclusion list
  of non-entity types (`String`, `int`, `double`, `bool`, `DateTime`, `Object`,
  `dynamic`, `void`, params types). **`Duration` is missing.**
- `lib/src/utils/entity_type_validator.dart:96-132` — calls
  `extractEntityTypes` and rejects any returned type with no matching entity
  directory or `enums/<snake>.dart` file.
- `lib/src/commands/entity_command.dart:183-208` — the abort branch that prints
  the error and `exit(1)` before writing anything.
- `lib/src/core/constants/known_types.dart:24` — `dartTypes` already contains
  `Duration`, so import generation was always correct; only the entity-type
  extractor disagreed.

## Root Cause Hypothesis

`Duration` is a dart:core type but is absent from the `extractEntityTypes`
exclusion list. Because it starts with an uppercase letter, the heuristic
classifies it as a custom entity/enum reference. The #296 pre-write validator
then finds no `duration/duration.dart` entity and no `enums/duration.dart`, so
`zfa entity create` aborts before writing. The inconsistency with
`KnownTypes.dartTypes` (which already excludes `Duration`) confirms the
omission is an oversight, not a policy.

## Proposed Remediation

Add `'Duration'` to the exclusion list in `EntityUtils.extractEntityTypes`,
with a comment pointing at `KnownTypes.dartTypes` and this issue. This makes
`Duration` behave exactly like `DateTime` — accepted as a field type, no import
emitted, no validation error. Minimal, single-list change; no new dependencies.

## Files likely to change

| File | Change |
|------|--------|
| `lib/src/utils/entity_utils.dart` | add `'Duration'` to the non-entity type list |
| `test/utils/entity_utils_test.dart` | new focused unit test |

## Tests to add

- `Duration`, `Duration?`, `List<Duration>`, `Map<String, Duration>` all yield
  no entity types.
- Other primitives remain excluded (no regression).
- Genuine references (`Product`, `$Product`, `List<Product?>`, `FeedbackType`)
  are still extracted.

## Risks & Considerations

- Widening the exclusion list means a *user-defined entity actually named*
  `Duration` would no longer be resolved — acceptable, since shadowing a
  dart:core type is already unsupported elsewhere (`DateTime` behaves the same).
- The sibling `../zorphy` path checkout does not compile in this environment
  (`'ParameterElement' isn't a type.`), so any test importing `package:zorphy`
  cannot load. Tests were therefore written against `EntityUtils` directly,
  which has no zorphy dependency.

## Open Questions

- None.
