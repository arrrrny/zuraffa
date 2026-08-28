# Bug Assessment: zfa entity sealed: generates subtypes as separate libraries implementing sealed class → invalid_use_of_type_outside_library

- **Slug**: issue-416-zfa-entity-sealed-generates-subtypes-as-separate-libraries-i
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Refined**: 2026-08-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/416
- **Verdict**: valid, but **root cause is outside this repository**
- **Severity**: high for sealed hierarchies with `--generate-subs`

## Report (verbatim or summarized)

`zfa entity create -n EngineEvent --sealed --subtypes "MissionStarted,..."
--generate-subs` emits every subtype as its own library containing
`class MissionStarted implements EngineEvent { ... }`. Dart forbids implementing
a sealed class from another library → `invalid_use_of_type_outside_library`
(one per subtype).

## Symptom

Nine standalone subtype files, each its own library, each referring to the
sealed parent; `dart analyze` fails on every one.

## Suspected Code Paths

Traced end-to-end:

1. `lib/src/commands/entity_command.dart:214-232` — builds `EntityConfig` with
   `isSealed: parsed['sealed']`,
   `explicitSubtypes: _asStringList(parsed['subtypes'])`,
   `generateSubtypes: parsed['generate_subs']`.
2. `lib/src/commands/entity_command.dart:234-235` — hands the config to
   `EntityCreator(...).create(config)`.
3. **`EntityCreator` is `package:zorphy` (`lib/src/cli/entity_creator.dart`),
   not this repo.** `create()` writes the parent entity, then (lines 64-67)
   calls `generateSubtypeFiles(normalizedConfig, {})`, which loops over
   `explicitSubtypes` and writes one *separate file per subtype* with
   `extendsInterface: <parent>` — exactly the construct the issue reports.
4. `zorphy/lib/src/cli/services/import_resolver.dart:72` is the only other place
   reacting to `generateSubtypes && isSealed` (import emission).

`grep -rn "generateSubtypes" lib/src` in zuraffa returns exactly one hit (the
flag pass-through at `entity_command.dart:226`). No sealed-subtype file-emitting
code exists in zuraffa.

## Root Cause Hypothesis

`ZorphyEntityCreator.generateSubtypeFiles` emits each subtype as its own library
that `implements` the sealed parent. Since Dart 3, all direct subtypes of a
`sealed` class must live in the parent's library, so the generated code cannot
compile. The remediation (emit subtypes into the parent's file, or use
`part`/`part of`, or drop `sealed` when subtypes are external) must be
implemented in `arrrrny/zorphy`.

## Proposed Remediation

**Upstream (zorphy)**: in `generateSubtypeFiles`, when
`parentConfig.isSealed == true`, append the subtype declarations to the parent
entity library (or emit `part of '<parent>.dart';` headers plus matching `part`
directives in the parent) instead of writing independent libraries.

**Optionally in zuraffa** (deliberately not applied): a guard in
`entity_command.dart` rejecting `--sealed --generate-subs` with an explanatory
message. That masks the bug rather than fixing it and would need reverting once
upstream lands.

## Files likely to change

| Repo | File |
|------|------|
| arrrrny/zorphy | `lib/src/cli/entity_creator.dart` (`generateSubtypeFiles`) |
| arrrrny/zorphy | `lib/src/cli/services/import_resolver.dart` (subtype imports become unnecessary) |
| arrrrny/zuraffa | none |

## Tests to add

Belongs upstream: a zorphy CLI test asserting that with `isSealed: true` and
`generateSubtypes: true`, no separate library declares `implements <sealed>` —
subtypes are emitted into (or as a `part of`) the parent library.

## Risks & Considerations

- Fixing this inside zuraffa would require either duplicating zorphy's subtype
  generator or post-processing its output — both out-of-scope workarounds that
  violate the minimal-fix constraint.
- End-to-end reproduction was additionally blocked locally: the sibling
  `../zorphy` checkout does not compile in this environment
  (`helpers.dart:894: 'ParameterElement' isn't a type.`), so `zfa entity create`
  cannot be run here at all.

## Outcome

**Skipped for this pass — not fixable in `zuraffa/lib/src`.** The issue should be
transferred to (or mirrored in) `arrrrny/zorphy`.

## Open Questions

- Preferred upstream shape: subtypes inlined into the parent file, or `part of`
  files? This determines whether existing sealed entities need a migration.
