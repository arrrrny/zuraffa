# RED evidence — bug 1575

Command: `dart test test/plugins/tdd/services/test_list_reader_1575_fence_test.dart test/core/proof_chain_checker_1575_fence_test.dart` (Dart 3.13.3, pre-fix tree @ b621f38b)

## test_list_reader_1575_fence_test.dart — 5 failed / 3 passed

- FAILED `an in-fence loop marker does not re-kind the section`:
  `Expected: BehaviorKind:<BehaviorKind.acceptance>  Actual: BehaviorKind:<BehaviorKind.unit>`
  — the in-fence `## Inner loop:` banner flipped the section kind (site 346).
- FAILED `an in-fence declarative marker does not swallow real rows`:
  `Expected: ['U1', 'U2']  Actual: ['U1']`
  — the in-fence `## Key entities` banner switched the walk into the
  declarative section; U2 silently vanished (site 346).
- FAILED `readEntities — an in-fence header does not close the section`:
  `Expected: ['Role', 'Widget']  Actual: ['Role']` (site 485).
- FAILED `readDependencies — an in-fence header does not close the section`:
  `Expected: ['AuthApi', 'Clock']  Actual: ['AuthApi']` (site 533).
- FAILED `readLayerContracts — an in-fence header does not close the section`:
  `Expected: ['IRepo', 'IStore']  Actual: ['IRepo']` (site 571).
- PASSED controls: well-formed list without fences; the committed 004
  corpus shape (in-fence `## Baseline (...)`); malformed-row line-number
  contract (line 7 pinned).

## proof_chain_checker_1575_fence_test.dart — 2 failed / 1 passed

- FAILED `an in-fence header does not drop post-fence behavior ids`:
  gap for `"B2"` missing — the in-fence `## Notes:` banner switched
  `inBehaviorSection` off and B2 silently dropped out of the audit (site 1068).
- FAILED `a fenced ## Behaviors example fabricates no phantom ids`:
  `PHANTOM` id WAS fabricated — the in-fence `## Behaviors (example)`
  banner re-armed the behavior-section walk inside a declarative section.
- PASSED control: well-formed behaviors table audits exactly as before.

Failure modes match issue #1575 verbatim: rows/ids vanish with no error,
kinds flip, phantom rows fabricated — all triggered by `## ` lines inside
fenced code blocks.
