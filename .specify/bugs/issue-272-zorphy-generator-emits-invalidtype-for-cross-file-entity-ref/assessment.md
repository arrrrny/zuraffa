# Bug Assessment: zorphy generator emits InvalidType for cross-file entity references

- **Slug**: issue-272-zorphy-generator-emits-invalidtype-for-cross-file-entity-ref
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/272
- **Verdict**: upstream — root cause lives in the external `zorphy` package, not in `lib/src`
- **Severity**: task/v6/zuraffa_core (per labels)

## Report (verbatim or summarized)

A `@Zorphy` entity referencing another entity in a DIFFERENT file (e.g.
`B get b;` in `a.dart`, `B` defined in `b.dart`) generated
`final InvalidType b;` in the `.zorphy.dart` output for both direct-import and
barrel-reexport styles.

## Symptom

`final InvalidType b;` (and `InvalidType? b`) emitted in the generated
`.zorphy.dart` part; `build_runner` reports the failure.

## Reproduction

Minimal repro under `lib/src/domain/entities/ref/`:
- `b.dart`: `@Zorphy(generateJson: true) abstract class $B { String get id; }`
- `a.dart`: imports `b`, parts `a.g.dart`+`a.zorphy.dart`, `@Zorphy abstract class $A { String get id; B get b; }`
- `entities.dart`: exports both.

## Suspected Code Paths

- The Zorphy **generator** (`ZorphyGenerator`), which emits the `.zorphy.dart`
  part. In this repo `zorphy` is an external pub dependency (`zorphy: ^2.2.0`,
  `zorphy_annotation: ^2.2.0` in `pubspec.yaml`); the generator source is NOT
  in `lib/src`.
- `lib/src/utils/entity_type_validator.dart` and
  `lib/src/commands/entity_command.dart` are zuraffa-side *guards* (issue #296)
  that reject unresolved field types at `zfa entity create` time — they do NOT
  emit the `.zorphy.dart` cross-file references.

## Root Cause Hypothesis

The Zorphy generator resolved cross-file referenced types by name string
rather than via analyzer elements, emitting `InvalidType` when the referenced
type lived in another file. This is a bug in the `zorphy` package generator.

## Proposed Remediation

Cannot be fixed within `lib/src` — the generator lives in the `zorphy`
package. The issue author's own comment (2026-08-13) confirms it is **fixed on
the zorphy toolchain** (zuraffa `a8f3354` + zorphy development `85de507`):
`final Country country;` is generated correctly with zero `InvalidType`
occurrences. The zuraffa-side #395 "emit imports for referenced entities" is a
*separate* generator (provider/service method import depth), not the Zorphy
cross-file fix.

## Files likely to change

- `zorphy` package generator (out of scope for this repo's `lib/src`).

## Tests to add

- A zuraffa-side regression test would require running `build_runner` codegen
  against the `zorphy` generator (heavy; regression tier) and is blocked by the
  same toolchain dependency. Out of scope for a `lib/src`-only fix.

## Risks & Considerations

- Fix belongs upstream in `zorphy`; this repo can only bump the dependency
  once a pub release carrying the fix exists (current `^2.2.0` pin).

## Open Questions

- Whether `zorphy ^2.2.0` on pub.dev already contains the cross-file fix; the
  author verified it only against zorphy `development` (`85de507`).
