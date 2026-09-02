# Bug Issue: zfa tdd init writes tdd-profile Commands bullets with stray trailing quotes (both Dart and Flutter profiles)

- **Slug**: tdd-profile-quotes
- **Fetched**: 2026-09-02
- **Issue**: 756
- **URL**: https://github.com/arrrrny/zuraffa/issues/756
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd init` generates `.specify/memory/tdd-profile.md` whose **Commands** section is malformed: every bullet ends with a stray single quote **outside** the closing backtick. The defect lives in one shared render template, so **both** profile variants (Dart and Flutter) are affected.

## Location (master @ e3a183d6)

`lib/src/cli/writers/tdd/tdd_profile_writer.dart`, `_render` (lines 168–171):

```dart
- Single test: `${p.resolveSingle(file: '{file}', name: '{name}')}'
- Whole file: `${p.resolveFile('{file}')}'
- Full suite: `${p.resolveSuite()}'
- Coverage: `${p.resolveCoverage()}'
```

Each line closes the interpolation backtick and then emits a stray `'`. Raw bytes from a generated file confirm: ``--name "{name}"'$`` — quote after the closing backtick.

## Sightings (two independent repos)

1. `arrrrny/zuraffa_permissions`#4 — Flutter profile (filed first, repaired by hand in that repo's TDD cycle).
2. `arrrrny/zuraffa_auth` — Dart profile, regenerated with the same defect during this week's full-zfa-TDD cycle (repaired by hand again).

The machine-readable **Keys** block further down the same file is correctly quoted, so tooling reading Keys is unaffected — but the human-readable Commands section that agents/humans copy commands from is malformed in every generated project.

## Secondary: single-command drift between the two profiles

`lib/src/plugins/tdd/models/tdd_profile.dart`:

- line 22 (Flutter): `single: 'flutter test {file} --plain-name "{name}"'`
- line 30 (Dart): `single: 'dart test {file} --name "{name}"'`

`--name` is the regex matcher, `--plain-name` the literal substring matcher. The TDD loop targets behaviors by id (e.g. `--plain-name "U1:"`); for id-shaped targets both work, but any behavior name containing regex metacharacters breaks the Dart variant, and the two profiles disagree for no evident reason. Suggest aligning the Dart profile on `--plain-name` while fixing the bullets.

## Suggested fix

In `tdd_profile_writer.dart` lines 168–171, drop the stray `'` after each closing backtick (and optionally align `dart single` to `--plain-name` in `tdd_profile.dart:30`). Both repairs are one-liners in the template; regenerated profiles then match the already-repaired hand fixes in the two consumer repos.

## Comments

None.
