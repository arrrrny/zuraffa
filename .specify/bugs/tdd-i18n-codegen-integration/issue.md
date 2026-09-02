# Bug Issue: [TDD-120] i18n codegen integration: slang inside the TDD loop

- **Slug**: tdd-i18n-codegen-integration
- **Fetched**: 2026-09-02
- **Issue**: 834
- **URL**: https://github.com/arrrrny/zuraffa/issues/834
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Specs 006/091 require: keys exist across 7 locales + variants, locale resolution fallback, instant switching. `zfa tdd` currently cannot drive codegen-backed assertions.

Required (system fix):
1. `zfa tdd gen` locale-kind behaviors emit tests that call the generated `t.` API (slang) — meaning the loop must run `dart run slang` as a build step (like `zfa build`) when translation sources change.
2. Coverage gate as a TEST (not a lint): generated test asserts every key present in en exists in de/es/pl/ro/ru/tr (+country variants) — red when a key is missing, green when complete. This turns FR/SC of spec 006 into executable proof.
3. Locale-resolution subjects: pure functions over the supported-locale table — generated from the locale manifest, not hand-written.

## Comments

None.