# Bug Spec: 1535 — tdd-profile `single:` template parsing (YAML escapes + unknown placeholders)

- **Slug**: 1535-tdd-profile-yaml-escape-placeholder
- **Source**: https://github.com/arrrrny/zuraffa/issues/1535 (see ./issue.md, ./assessment.md)
- **Kind**: bug (profile-template parsing; parser-only remediation)

## Problem

The `SingleTestRunner` profile loader mis-handles two profile authoring styles for
the `single:` command template:

1. YAML **double-quoted** scalars carry escape sequences (`\"`) which are captured
   verbatim and never unescaped — the `--plain-name` argument arrives with literal
   backslash-quotes, matches zero tests (exit 79), and an honest red is classified
   `runner-error`.
2. **Unknown legacy placeholder spellings** (e.g. the two-word `<test name>`) pass
   through `_normalize` untouched, get shredded by whitespace tokenization, and an
   honest red is classified `load-error`.

Both misclassify an honest red and dead-end `zfa tdd run` at verify-red with
misleading remedies.

## Acceptance criteria (the fixed behavior)

- **AC-1** — A `single:` value extracted from a YAML **double-quoted** scalar has
  its escape sequences unescaped before placeholder normalization and substitution
  (`\"` → `"`, `\\` → `\`, `\n` → LF, `\t` → TAB, `\r` → CR, `\0` → NUL, plus the
  `\x..` / `\u....` hex escapes). Single-quoted and unquoted scalars are NOT
  backslash-processed (single-quoted YAML has no backslash escapes).
- **AC-2** — Unknown placeholder spellings are rejected at profile **load time**
  with a `StateError` whose message names the accepted placeholders (`{file}`,
  `{name}`) and the remedy (rewrite the profile key with the accepted spellings).
  Legacy single-word spellings `<path>`, `<file>`, `<name>` remain accepted via
  normalization.
- **AC-3** — A `single:` template written as a double-quoted YAML scalar with
  `{file}`/`{name}` and escaped quotes (`single: "dart test {file} --plain-name \"{name}\""`)
  executes correctly: the honest-red fixture test runs (testCount == 1) and
  classifies as `RedClassification.assertion`.
- **AC-4** — The previously-working single-quoted form
  (`single: 'dart test {file} --plain-name "{name}"'`) and the human-facing
  `- Single test:` bullet with `<path>`/`<name>` keep working unchanged
  (no regression, no over-escaping).

## Failing-test scenario (reproduction from the issue)

```yaml
# .specify/memory/tdd-profile.md — Keys (machine-readable) block:
single: "dart test {file} --plain-name \"{name}\""   # escaped quotes → today: runner-error (exit 79)
single: "dart test <file> --plain-name \"<test name>\""  # unknown placeholder → today: load-error
```

Run `loadSingleTemplate` → `runSingle` against the TddFixture's honest-red test.

## Constraints

- Fix the profile template **parsing only** (runner.dart loader/_normalize side).
- Do NOT change verify-red certification logic, the red classifier, or process
  spawning (hard constraint from the issue).
- One PR per bug; `Closes #1535`.
