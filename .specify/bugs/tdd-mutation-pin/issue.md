# Bug Issue: zfa tdd init pins mutation_test ^1.0.0 while the toolchain's MutationVerifier parses the v1.8.0+ report format

- **Slug**: tdd-mutation-pin
- **Fetched**: 2026-09-02
- **Issue**: 755
- **URL**: https://github.com/arrrrny/zuraffa/issues/755
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd init` writes `mutation_test: ^1.0.0` into the generated project's `dev_dependencies`, but the same toolchain's wired mutation verifier documents and parses the **mutation_test v1.8.0+** report format. Every project initialized by the CLI gets a baseline whose mutation-tool pin predates the report format the toolchain itself expects — the generated baseline is internally inconsistent out of the box.

## Locations (master @ e3a183d6)

The pin — both profile maps of `PubspecDevDependenciesPatcher`:

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:26` (`flutterDevDependencies`)
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:35` (`dartDevDependencies`)

The parser that requires the newer format:

- `lib/src/plugins/tdd/services/mutation_verifier.dart:235` — "The mutation_test package (v1.8.0+) emits these in …"
- `lib/src/plugins/tdd/services/mutation_verifier.dart:255` — `// OR "Detected by: test N" (mutation_test v1.8+ format).`

## Reproduction (real run, this week)

During the full-zfa-TDD cycle on `arrrrny/zuraffa_auth` (private repo; earlier sighting of the sibling defect class: zuraffa_permissions#4):

1. `zfa tdd init` (zfa 6.1.0, Dart mode) added `mutation_test: ^1.0.0` to the target's `dev_dependencies`.
2. The project requires `^1.8.0` (the stack's verifier parses v1.8.0+ reports), so the pin had to be hand-raised immediately after init.
3. With `^1.8.0`, pub resolves `mutation_test 1.8.0` cleanly — the bump is a one-line change with no downstream conflicts.

## Suggested fix
Also remove the unused mocktail dev dependency install on zfa tdd init. and also use the latest version of covearge package ^1.15.1 or whatever the current latest is.
Bump both maps in `pubspec_dev_dependencies_patcher.dart` from `mutation_test: '^1.0.0'` to `mutation_test: '^1.8.0'` so the generated baseline and the toolchain's own verifier agree. If older report formats are intentionally still supported somewhere, a version guard in the verifier would be the alternative — but then the generated pin should match that floor.

## Secondary wart (same file)

`_patchTextually` splices the missing entries at the next top-level key without blank-line preservation: the two new dev_dependencies land after a blank line mid-section, and the following top-level key (e.g. `dependency_overrides:`) ends up glued directly against the last entry. Valid YAML, sloppy output — worth fixing while touching this file.

## Comments

None.
