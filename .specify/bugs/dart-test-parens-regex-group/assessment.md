# Bug Assessment: dart test -n treats parens as regex group — blocks behaviors with (sticky) or (FR-XXX)

- **Slug**: tdd-parens-regex
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/760
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd verify-red` and `zfa tdd make` pass the test name directly to `dart test -n "<name>"` without escaping regex metacharacters. When the behavior description contains parentheses (e.g. `(sticky)`, `(idempotent)`, `(FR-XXX)`), `dart test -n` treats them as a regex group, causing either no match (exit 79) or unintended test selection. https://github.com/arrrrny/zuraffa/issues/760

## Symptom

`zfa tdd run` blocks on any behavior whose description contains `(...)` or other regex metacharacters. `dart test -n` reports "No tests match regular expression" (exit 79), and `verify-red` classifies as `runner-error`.

## Reproduction

1. `zfa tdd init` on a pure Dart package
2. `zfa tdd run <feature>` — succeeds for behaviors without parens (U1, U2)
3. Stops at U3: description ends with `(sticky)`
4. `dart test -n "U3 (FR-005, FR-006) ..."` → "No tests ran." exit 79
5. `verify-red` classifies as `runner-error`

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart` — `SingleTestRunner.runSingle()` builds the `dart test -n <name>` command from the `single` template via `.replaceAll('{name}', name)` — no regex escaping.
- `lib/src/plugins/tdd/services/runner.dart` — `_substitute` / `_tokenize` methods that perform the template substitution. The `{name}` token is replaced verbatim without any escaping of regex metacharacters.
- `dart test -n` itself accepts a regex, not a literal string — this is the mismatch.

## Root Cause Hypothesis

High confidence: `SingleTestRunner._tokenize` (or `_substitute`) performs a plain `.replaceAll('{name}', name)` substitution without escaping regex metacharacters. Since `dart test -n` interprets the argument as a regex, parentheses, dots, brackets, etc. in the behavior name change the matching semantics. The previous tdd cycle log (spec 044/046) already noted this exact problem.

## Proposed Remediation

**Preferred**: Escape regex metacharacters in `_substitute` / `_tokenize` before substituting `{name}` into the template. Add an `_escapeRegExp` helper that escapes `\. ^$*+?()[]{}|` characters, and apply it to the `name` value before `replaceAll`. This is a one-line change per substitution site with zero behavior change for names without metacharacters.

**Alternatives** (optional):
- Switch from `dart test -n` to `dart test --plain-name` (package:test 1.25+). Requires verifying the installed `package:test` version supports `--plain-name`, and updating the `single:` template default. More future-proof but a larger change.

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` — add `_escapeRegExp` helper, apply in `_substitute` / `_tokenize`
- Test file (to be added) — a slow-tier test asserting the planner's emitted argv for a behavior with parens matches the real `dart test` command with escaped name

**Tests to add or update**:
- A test that creates a behavior with a name containing `(parens)` and asserts the emitted `dart test -n` command escapes them correctly (e.g. `dart test -n "U3 \(FR-005\)"` rather than `dart test -n "U3 (FR-005)"`).

## Risks & Considerations

- Minimal risk: the fix only adds escaping to the test-name substitution, no behavior change for names without metacharacters.
- Verify that the escaped form still matches correctly with `dart test -n` (it should — escaped parens match literal parens).
- Check if other template substitution sites (`{file}`, etc.) also need escaping — file paths rarely have regex metacharacters but should be confirmed.

## Open Questions

- [NEEDS CLARIFICATION: Does the project use `--plain-name` anywhere already? If so, prefer that flag over regex escaping for consistency.]
