# Bug Issue: tdd-profile `single:` template — `<test name>` placeholder and YAML `\"` escapes not handled → honest red misclassified as load-error / runner-error (exit 79)

- **Slug**: 1535-tdd-profile-yaml-escape-placeholder
- **Fetched**: 2026-09-15T17:29:20Z
- **Issue**: 1535
- **URL**: https://github.com/arrrrny/zuraffa/issues/1535
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

## Environment

- zfa v6.2.2 (Mach-O release binary)
- Repo: zuraffa_agent (pure Dart package, `package:test`)
- `.specify/memory/tdd-profile.md` written by the speckit-tdd-setup profile format (frontmatter `single:` key)

## Symptom

`zfa tdd run <feature>` stops at the first behavior's `verify-red` with a **wrong verdict**. The generated test is an honest red (assertion failure on the `UnimplementedError` stub) when run manually, but verify-red refuses to certify it:

Observed sequence on the same honestly-red test:

1. Profile value `single: "dart test <file> --plain-name \"<test name>\""` (double-quoted YAML with escapes, two-word placeholder) →
   `classification: load-error`, remedy says "restore the missing test file or import" — **the test file and subject both exist and compile**.
2. Profile value `single: "dart test {file} --plain-name \"{name}\""` (correct `{file}`/`{name}` placeholders, still YAML-escaped quotes) →
   `classification: runner-error`, `runner exit: 79` (zero tests matched).
3. Profile value `single: 'dart test {file} --plain-name "{name}"'` (single-quoted YAML) →
   `classification: assertion`, `certified=true` ✅ — the only form that works.

## Root cause (zfa `lib/src/plugins/tdd/services/runner.dart`)

Two stacked defects in profile-template handling:

1. **`_normalize` maps only `<path>`, `<file>`, `<name>`** — the two-word `<test name>` placeholder spelling survives normalization. `_tokenize` then splits the template on whitespace BEFORE substitution, so `--plain-name "<test name>"` becomes the two argument tokens `"<test` and `name>"`; dart test reads `name>` as a positional **path** that does not exist → load error → classified `load-error` with a misleading remedy.
2. **YAML double-quoted scalar escapes are never unescaped.** The `single:` value regex captures `\"` sequences verbatim, so the substituted `--plain-name` argument arrives as `\"both records arrive…\"` with literal backslash-quote characters; `--plain-name` is a literal substring matcher, no test name contains `\"` → zero tests ran → exit 79 → classified `runner-error`.

Both failure modes misclassify an honest red and stop the run (run-state `stopped_at=<id>:verify-red`), i.e. the loop dead-ends on a profile its own toolchain accepted.

## Repro

```yaml
# .specify/memory/tdd-profile.md frontmatter — BROKEN forms:
single: "dart test <file> --plain-name \"<test name>\""   # → load-error
single: "dart test {file} --plain-name \"{name}\""        # → runner-error, exit 79
# WORKING form:
single: 'dart test {file} --plain-name "{name}"'
```

Then: `zfa tdd gen <behavior> && zfa tdd verify-red <behavior> --feature <feature>` against a stub subject.

## Expected

- YAML scalar escapes in profile values are unescaped (double-quoted style per YAML spec), and/or
- unknown placeholder spellings are rejected at profile load time with a named remedy naming the exact accepted placeholders (`{file}`, `{name}`), instead of surfacing as `load-error`/`runner-error` at verify-red with remedies about missing files.

## Discovered while

zuraffa_agent spec 112 (structured logging), first `zfa tdd run` on a fresh feature; worked around in-repo by rewriting the profile `single:` value in single-quoted YAML form.

## Comments

None.
