# Bug Assessment: bin/zfa.dart still missing, zfa tdd refactor fails

- **Slug**: bin-zfa-dart-missing
- **Created**: 2026-09-01T17:23:21Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/717
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd refactor` calls `dart run bin/zfa.dart build` as a refactor pass, but `zfa setup` does not create `bin/zfa.dart` in the generated project. The CLI only exists at the system level (`~/.local/bin/zfa` on the user's machine). Result: refactor step hard-fails with exit 255.

See: https://github.com/arrrrny/zuraffa/issues/717

## Symptom

`zfa tdd refactor <behavior>` hard-fails at the `build` pass with `dart run bin/zfa.dart build` returning exit 255, because `bin/zfa.dart` is missing. The whole `zfa tdd refactor` invocation aborts with `misfire-stop`.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `zfa tdd verify-red A7 --feature=001-app-bootstrap`
7. `zfa tdd make A7 --feature=001-app-bootstrap`
8. `zfa tdd refactor A7 --feature=001-app-bootstrap` → exit 1

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Likely candidates:
- `lib/src/cli/commands/tdd/refactor_command.dart` (the `dart run bin/zfa.dart build` invocation)
- `lib/src/cli/commands/setup*.dart` or `lib/src/cli/writers/setup/*.dart` (where `bin/zfa.dart` would be generated)

## Root Cause Hypothesis

Two-part bug:
1. `zfa setup` does not scaffold `bin/zfa.dart` in the project.
2. `zfa tdd refactor` hard-codes `dart run bin/zfa.dart build` as the refactor pass command, which assumes the project-local binary exists.

The user reports the v6.1.0 binary at `~/.local/bin/zfa` is the actual system CLI; the project-local `bin/zfa.dart` is no longer created.

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Two possible fixes (the assessor needs to choose):
A. Make `zfa setup` scaffold a `bin/zfa.dart` passthrough to the system `zfa` CLI.
B. Make `zfa tdd refactor`'s build pass discover and call the system `zfa` directly (e.g. `zfa build` via PATH lookup), instead of `dart run bin/zfa.dart build`.

Option B is cleaner because it removes the assumption that the project is a Dart package with a `bin/` entrypoint.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- If the project IS expected to be a Dart package with a `bin/zfa.dart` entrypoint (e.g. for self-publishing), option A is the right fix and option B would diverge from intent.
- The user's workaround hard-codes a path (`/Users/ahmettok/.local/bin/zfa`); a robust fix must not depend on the user's home directory.
- Other refactor passes besides `build` may have the same problem.

## Open Questions

- [NEEDS CLARIFICATION: is the system `~/.local/bin/zfa` the canonical CLI entry point, or is `bin/zfa.dart` the canonical entry point that `zfa setup` should be creating?]
- [NEEDS CLARIFICATION: are there other refactor passes besides `build` that hard-code `dart run bin/zfa.dart <args>`?]
- [NEEDS CLARIFICATION: is this the only command in the tdd suite that shells out to `bin/zfa.dart`, or do `plan`/`gen`/`verify-red`/`make` also?]
