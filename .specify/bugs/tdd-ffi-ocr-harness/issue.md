# Bug Issue: [TDD-120] FFI + OCR harness: native-boundary behaviors must be TDD-able

- **Slug**: tdd-ffi-ocr-harness
- **Fetched**: 2026-09-02
- **Issue**: 835
- **URL**: https://github.com/arrrrny/zuraffa/issues/835
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Specs 082 (PDF→Markdown FFI), 032 (invoice OCR/tesseract), 081 (markdown product config) cross the FFI boundary. No current TDD surface for them.

Required (system fix):
1. `zfa tdd gen` ffi-kind behaviors: golden input/output fixtures (sample PDF → expected markdown) asserted through the same FFI binding used in production, executed on the host runner.
2. Where the native lib cannot load in test env, the generated test asserts the binding CONTRACT (symbols resolved, marshalling round-trips) and the fixture-level assertion runs in a marked integration lane wired to CI — still a gate, never skipped silently.
3. OCR: image fixtures + expected extraction JSON; tolerance thresholds encoded in the scenario script (deterministic seeds).

## Comments

None.