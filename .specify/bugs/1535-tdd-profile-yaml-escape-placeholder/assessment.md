# Bug Assessment: tdd-profile `single:` template — `<test name>` placeholder and YAML `\"` escapes not handled

- **Slug**: 1535-tdd-profile-yaml-escape-placeholder
- **Created**: 2026-09-15T17:29:20Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1535
- **Verdict**: valid (reproduced by code-path analysis; failing tests written in TDD red phase)
- **Severity**: high — blocks `zfa tdd run` at verify-red for a profile the toolchain itself accepted; honest red misclassified

## Report (verbatim or summarized)

Issue #1535 reports that `zfa tdd run <feature>` dead-ends at the first behavior's `verify-red` with a wrong verdict when the TDD profile's `single:` template is written in certain YAML styles. Three profile spellings were tried against the same honestly-red test:

1. `single: "dart test <file> --plain-name \"<test name>\""` → `classification: load-error` (test file exists and compiles).
2. `single: "dart test {file} --plain-name \"{name}\""` → `classification: runner-error`, exit 79 (zero tests matched).
3. `single: 'dart test {file} --plain-name "{name}"'` → `classification: assertion`, `certified=true` — the only working form.

## Symptom

verify-red refuses to certify an honest red (assertion failure on the `UnimplementedError` stub), misclassifying it as `load-error` or `runner-error` with remedies about missing files, so the TDD loop stops at `stopped_at=<id>:verify-red`.

## Reproduction

1. Write `.specify/memory/tdd-profile.md` frontmatter with `single: "dart test {file} --plain-name \"{name}\""` (double-quoted YAML, escaped quotes).
2. Run `zfa tdd gen <behavior> && zfa tdd verify-red <behavior> --feature <feature>` against a stub subject.
3. Observed: `classification: runner-error` (exit 79, zero tests matched) instead of `classification: assertion` / certified red.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart`
  - `_normalize` (line ~337): maps only `<path>`, `<file>`, `<name>`; any other legacy spelling (e.g. the two-word `<test name>`) survives into tokenization.
  - `_tokenize` (line ~513): splits the template on whitespace BEFORE substitution, so an un-normalized two-word placeholder breaks into two argument tokens; `dart test` reads the second fragment (`name>"`) as a positional path → load error.
  - `_firstMatchValue` / key extraction regexes (lines ~119, ~144, ~154, ~197, ~274): capture the YAML scalar verbatim — double-quoted escape sequences (`\"`) are never unescaped, so the `--plain-name` argument arrives as `\"…\"` with literal backslash-quotes → zero matches → exit 79 → `runner-error`.

## Root Cause Hypothesis

Two stacked defects in profile-template handling (confirmed by reading `runner.dart`):

1. `_normalize` covers only the single-word legacy placeholders `<path>`/`<file>`/`<name>`; unknown spellings like `<test name>` pass through, and `_tokenize`'s split-on-whitespace shreds them into bogus arguments.
2. YAML double-quoted scalar escapes are captured verbatim and never unescaped; `--plain-name` is a literal substring matcher, so `\"name\"` matches nothing.

Both failure modes misclassify an honest red and stop the run.

## Proposed Remediation

Fix the profile template parsing in `lib/src/plugins/tdd/services/runner.dart` ONLY (no verify-red certification logic, no test-runner changes):

1. **Unescape YAML double-quoted scalars**: when the extracted `single:`/`file:`/`suite:` value came from a double-quoted YAML scalar, unescape the YAML double-quoted escape sequences (`\"` → `"`, `\\` → `\`, `\n`, `\t`, `\r`, `\0`, `\x..`, `\u....`, …) before placeholder normalization and substitution. Single-quoted and unquoted scalars are untouched (single-quoted style has no backslash escapes).
2. **Reject unknown placeholder spellings at load time**: after legacy normalization, scan the template for remaining placeholder-like tokens (`<...>` or `{...}`); anything other than the accepted `{file}`/`{name}` throws a `StateError` at load time that names the accepted placeholders and the remedy (rewrite the profile key with `{file}`/`{name}`).
3. Files likely to change: `lib/src/plugins/tdd/services/runner.dart` (parsing only), plus new tests in `test/plugins/tdd/bug_1535_profile_template_parsing_test.dart`.

## Tests to add or update

- Red: `loadSingleTemplate` on a profile whose Keys block carries `single: "dart test {file} --plain-name \"{name}\""` (escaped quotes) must return the unescaped template `dart test {file} --plain-name "{name}"`; today it returns literal `\"` (RED assertion).
- Red: `loadSingleTemplate` on a profile with `single: "dart test <file> --plain-name \"<test name>\""` must throw a `StateError` naming the accepted placeholders (`{file}`, `{name}`); today it returns the broken template silently (RED assertion).
- Red→Green (end-to-end honest red): `runSingle` driven through the double-quoted escaped template against the TddFixture's honest-red test must classify as `RedClassification.assertion` with `testCount == 1`; today it classifies `runner-error` (exit 79) (RED assertion, green after fix).
- Guard: the single-quoted working form (issue case 3) keeps working unchanged (no regression, no over-escaping).
- Guard: legacy `<path>`/`<file>`/`<name>` bullet normalization keeps working.

## Risks & Considerations

- Must not change classification/certification logic or `Process` invocation — parser-only fix (hard constraint).
- Unescaping must apply ONLY to double-quoted scalars; applying backslash-unescaping to single-quoted/unquoted YAML values would corrupt templates that legitimately contain backslashes.
- Placeholder validation must run AFTER legacy normalization so `<path>`/`<file>`/`<name>` remain accepted spellings.
- The human-facing `- Single test:` bullet path also normalizes legacy placeholders; the same unknown-placeholder rejection applies there for consistent, early, named failures.
- Related: #1162 (re-certify), #1259 (vacuous-green), #1488 (vacuous-green gate) — none touched by this parser-only fix.

## Open Questions

- None blocking. Scope fixed by issue acceptance criteria.
