# Bug Issue: Key Entities fields silently dropped without backticks

- **Slug**: 1486-entity-fields-backtick-parsing
- **Fetched**: 2026-09-13
- **Issue**: 1486
- **URL**: https://github.com/arrrrny/zuraffa/issues/1486
- **State**: open
- **Severity**: critical (task brief; silent vacuous-green first signal)
- **Author**: arrrrny (task brief)
- **Labels**: bug, tdd (per brief; related: track-tdd-loop family)

## Body

### Summary

A `## Key Entities` row that declares fields in perfectly readable prose —
`| Task | id: String, title: String, isCompleted: bool, createdAt: String | purpose |`
— is parsed into a `SpecEntity` with **zero fields**, silently. Phase-0
generates a field-less entity; the first signal is a `vacuous-green` 28m
into the run.

### Root cause

`spec_parser.dart:361-363` (pre-fix numbering) — `_fieldPair` requires
backticks:

```dart
static final RegExp _fieldPair = RegExp(
  r'`([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^`]+)`',
);
```

Plain `name: Type` in a fields cell matches nothing. `SpecEntity.fields`
defaults to `const []`.

### Controlled experiment

| Fields row form | `SpecEntity.fields` | Generated |
|---|---|---|
| `\| Task \| id: String, title: String \|` (plain) | `[]` | `abstract class $Task {}` |
| `\| Task \| \`id: String\`, \`title: String\` \|` (backticked) | `[id:String, title:String]` | all fields present |

### Hard constraints

- Fix ONLY field-pair parsing in `spec_parser.dart`. Do NOT change the
  state machine, gen, or loop semantics.
- Must handle backticked, unbackticked, mixed, and 2-column forms.
- Backticked form must continue to work (backwards compatible).
- Must pass `dart analyze` with no new warnings.
- Related: #1480 (template gap), #1429, #1381, #781, #919, #829.

> **DISK HOUSEKEEPING:** Clean up after every phase. Check `df -h .`
> frequently.
