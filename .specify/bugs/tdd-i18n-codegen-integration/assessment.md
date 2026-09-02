# Bug Assessment: i18n codegen integration — slang inside the TDD loop

- **Slug**: tdd-i18n-codegen-integration
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/834
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Specs 006/091 require: keys exist across 7 locales + variants, locale resolution fallback, instant switching. `zfa tdd` currently cannot drive codegen-backed assertions. The TDD loop has no i18n codegen integration — generated tests don't call the `t.` API, no coverage gate exists, no locale-resolution subjects. Keys can be silently dropped across 7 locales. https://github.com/arrrrny/zuraffa/issues/834

## Symptom

UI specs 006 and 091 require multi-locale support (7 locales + variants, fallback, instant switching). `zfa tdd gen` emits plain-function subjects — no `t.` API calls, no locale coverage gate. Keys present in en may be missing from de/es/pl/ro/ru/tr without detection. The TDD loop cannot prove i18n completeness.

## Reproduction

1. Run `zfa tdd gen <id>` for a UI spec requiring i18n (e.g. spec 006)
2. Generated subject is a pure-function — no `t.` API calls
3. No coverage gate asserts locale key completeness
4. Keys silently dropped across locales — green despite missing translations

## Suspected Code Paths

- `zfa tdd gen` — no locale-kind behavior generation
- No `t.` API call generation
- No coverage gate for locale completeness
- No locale-resolution subjects generated from manifest

## Root Cause Hypothesis

High confidence: the TDD pipeline was designed without i18n codegen integration. Locale requirements are declared in specs but never turned into machine-executable tests. No `t.` API, no coverage gate, no locale subjects.

## Proposed Remediation

**Preferred**: (1) `zfa tdd gen` locale-kind behaviors emit tests that call the generated `t.` API (slang) — the loop must run `dart run slang` as a build step when translation sources change. (2) Coverage gate as a TEST (not a lint): generated test asserts every key present in en exists in de/es/pl/ro/ru/tr (+country variants) — red when a key is missing, green when complete. (3) Locale-resolution subjects: pure functions over the supported-locale table — generated from the locale manifest, not hand-written.

**Alternatives** (optional):
- Manual i18n testing — doesn't scale; VISION violation; not acceptable.

**Files likely to change**:
- Gen command (locale-kind behavior template)
- `dart run slang` integration in build pipeline
- Coverage gate test generation
- Locale manifest → subjects pipeline

**Tests to add or update**:
- Locale-kind A-behaviors generate tests with `t.` API calls
- Coverage gate: red when key missing from any locale, green when complete
- Locale-resolution subjects generated from manifest

## Risks & Considerations

- 2 specs directly affected (006, 091) plus every UI spec indirectly (translation keys)
- `dart run slang` must be available and fast enough for the loop
- Coverage gate must not be a lint (must be a TEST that can fail the loop)
- Locale manifest format must be consistent
- Depends on #827 (namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: What is the exact slang `t.` API format for generated tests?]
- [NEEDS CLARIFICATION: How does the coverage gate count country variants (en.phone vs en_phone)?]