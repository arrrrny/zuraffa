# Bug Verification: zorphy generator emits InvalidType for cross-file entity references

- **Slug**: issue-272-zorphy-generator-emits-invalidtype-for-cross-file-entity-ref
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: upstream / not fixable in `lib/src`

## Summary

The defect lives in the **Zorphy generator** (external `zorphy` pub
dependency), not in this repo's `lib/src`. The issue author confirms it is
fixed on the zorphy toolchain (zuraffa `a8f3354` + zorphy `85de507`), producing
`final Country country;` with zero `InvalidType` occurrences.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Generator location | grep `InvalidType` in `lib/src`, inspect `pubspec.yaml` | n/a | Zorphy generator is in the `zorphy` package (`^2.2.0`), not vendored. |
| zuraffa-side guards | `entity_type_validator.dart`, `entity_command.dart` | n/a | These guard unresolved field types at create time (issue #296), unrelated to Zorphy cross-file emission. |
| `dart analyze lib` | static check | pass | No errors introduced. |

## Output Excerpts

```
12 issues found.
   ✅ dart analyze: no errors
```

## Residual Risks

- This repo can only consume the fix once a `zorphy` pub release carrying the
  cross-file fix is published (current `^2.2.0` pin).

## Recommendation

Track the `zorphy` release; bump `pubspec.yaml` when available; close #272
once verified. No `lib/src` change is possible.
