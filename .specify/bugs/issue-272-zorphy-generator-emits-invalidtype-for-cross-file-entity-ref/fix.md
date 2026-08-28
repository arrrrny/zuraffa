# Bug Fix: zorphy generator emits InvalidType for cross-file entity references

- **Slug**: issue-272-zorphy-generator-emits-invalidtype-for-cross-file-entity-ref
- **Fixed**: n/a — root cause is upstream in the `zorphy` package (not `lib/src`)
- **Assessment**: ./assessment.md
- **Status**: upstream / out-of-scope for `lib/src` fix

## Summary

The `InvalidType` emission for cross-file entity references originates in the
**Zorphy generator**, which lives in the external `zorphy` pub dependency
(`zorphy: ^2.2.0`, `zorphy_annotation: ^2.2.0` — see `pubspec.yaml`). The
generator source is not in this repo's `lib/src`, so the bug cannot be fixed
here.

The issue author's own comment (2026-08-13) confirms it is **fixed on the
zorphy toolchain** (zuraffa `a8f3354` + zorphy development `85de507`):
`final Country country;` is generated correctly across all entity dirs with
zero `InvalidType` occurrences.

## Changes

| File | Change | Notes |
|------|--------|-------|
| (none in `lib/src`) | — | The zuraffa-side `#395` "emit imports for referenced entities" is a *separate* provider/service generator fix, not the Zorphy cross-file fix. |

## Diff Highlights

No `lib/src` diff is possible — the defect is in the `zorphy` package generator.

## Tests Added or Updated

- A zuraffa-side regression test would require running `build_runner` codegen
  against the `zorphy` generator (heavy; regression tier) and is blocked by the
  same toolchain dependency. Out of scope for a `lib/src`-only fix.

## Local Verification

- `dart analyze lib` shows no errors; the zuraffa-side `entity_type_validator`
  (issue #296 guard) correctly rejects unresolved field types at
  `zfa entity create` time but is unrelated to Zorphy's cross-file emission.

## Deviations from Assessment

The fix is upstream; this repo can only consume it once a pub release of
`zorphy` carrying the cross-file fix is available (current `^2.2.0` pin).

## Follow-ups

- Track the `zorphy` pub release that includes the cross-file reference fix and
  bump `pubspec.yaml` once published; close GitHub issue #272 when verified.
