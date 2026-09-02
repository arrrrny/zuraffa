# Bug Assessment: FFI + OCR harness — native-boundary behaviors must be TDD-able

- **Slug**: tdd-ffi-ocr-harness
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/835
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Specs 082 (PDF→Markdown FFI), 032 (invoice OCR/tesseract), 081 (markdown product config) cross the FFI boundary. No current TDD surface for them. The TDD loop cannot express FFI + OCR behaviors — no golden fixtures, no contract assertions, no OCR tolerance thresholds. These behaviors are completely untested. https://github.com/arrrrny/zuraffa/issues/835

## Symptom

FFI-crossing specs (032, 081, 082, 096, 093) have no TDD surface. Generated tests don't assert on FFI binding contracts. No OCR fixture assertions. These behaviors are entirely untested in the TDD loop.

## Reproduction

1. Run `zfa tdd gen <id>` for an FFI-backed feature (e.g. spec 032 OCR)
2. Generated subject has no FFI contract assertion
3. No OCR fixture-level assertions exist
4. Behavior has no test surface at all

## Suspected Code Paths

- `zfa tdd gen` — no FFI-kind behavior generation
- No golden fixture infrastructure
- No FFI contract assertion template
- No OCR tolerance threshold encoding

## Root Cause Hypothesis

High confidence: the TDD pipeline was designed without FFI + OCR harness. Native-boundary behaviors were never integrated — no golden fixtures, no contract assertions, no OCR support. The loop cannot test any behavior that crosses the FFI boundary.

## Proposed Remediation

**Preferred**: (1) `zfa tdd gen` ffi-kind behaviors: golden input/output fixtures (sample PDF → expected markdown) asserted through the same FFI binding used in production, executed on the host runner. (2) Where the native lib cannot load in test env, the generated test asserts the binding CONTRACT (symbols resolved, marshalling round-trips) and the fixture-level assertion runs in a marked integration lane wired to CI. (3) OCR: image fixtures + expected extraction JSON; tolerance thresholds encoded in the scenario script (deterministic seeds).

**Alternatives** (optional):
- Skip FFI testing — behaviors remain untested; VISION violation; not acceptable.

**Files likely to change**:
- Gen command (ffi-kind behavior template)
- FFI contract assertion template
- Golden fixture infrastructure
- OCR scenario script generation

**Tests to add or update**:
- FFI-kind A-behaviors generate tests with golden fixtures + contract assertions
- OCR fixture assertions with tolerance thresholds
- Integration lane wired to CI gate

## Risks & Considerations

- 4 specs directly affected (032, 081, 082, 096) plus 093 (screenshot generation)
- Golden fixtures must be deterministic and comparable
- FFI contract assertions must not false-positive on valid marshalling
- OCR tolerance thresholds must be deterministic (seeded)
- Depends on #827 (namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: What is the exact FFI contract assertion format for generated tests?]
- [NEEDS CLARIFICATION: What is the JSON schema for OCR scenario scripts?]