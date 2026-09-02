# Fix: FFI + OCR harness — native-boundary behaviors must be TDD-able (issue #835)

## What changed

The TDD loop had exactly two behavior kinds (`acceptance` / `unit`), both derived
from spec prose. An FFI-crossing behavior was unrepresentable: a hand-written
`ffi` kind cell was rejected as a malformed row, a `## Native loop` section was
rejected as a row outside an outer/inner loop, and an ffi-ish behavior declared
as a plain unit row got the generic function pair — a stub and an assertion that
never touch a binding, a fixture, or a native boundary. Six changes, one per
remediation surface (assessment: gen command template, contract assertion
template, golden fixture infrastructure, OCR scenario generation):

1. **A third loop kind.** `BehaviorKind.ffi` marks a native-boundary behavior.
   It is hand-declared, never derived from spec prose: the reader accepts an
   `ffi` kind cell in the deprecated 6-column dialect (kind cell wins over the
   section header, exactly like `acceptance`/`unit`) and a `## Native loop`
   section header for canonical 4-column rows. Genuinely unknown kinds still
   fail closed with the same malformed-row misfire-stop as before.
2. **The binding-contract harness.** For an ffi behavior the subject is no
   longer a function stub but a contract harness: the declared contract
   (`kNativeLibrary`, `kRequiredSymbols`) plus three seams — `symbolResolved`,
   `roundTrip`, `convertGolden` — each `throw UnimplementedError` until the
   implementer wires the SAME binding production uses. The harness carries no
   `dart:ffi` import so it compiles everywhere the loop runs; the adapter the
   implementer writes here is free to use it.
3. **The contract lane (remediation 2, default tier).** `BehaviorTestWriter`
   renders ONE test named exactly `<id> — <description>` (the registered
   runnable name; a two-test first draft failed `verify-red` with
   `runner-error` because the single-test contract matched zero tests — caught
   in this session and fixed before the fix landed) asserting the contract:
   every required symbol resolves, a payload round-trips through the binding
   unchanged. The `UnimplementedError` seams are captured into assertion
   failures, so the unwired state is an honest red the classifier certifies
   (`classification=assertion`) — never a thrown error, never a skip.
4. **The golden fixture lane (remediations 1–2, marked integration tier).**
   New `GoldenHarnessWriter` emits a second test tagged
   `@Tags(['integration', 'slow'])` (library-level annotation, before the first
   directive — a probe proved filtering ignores one attached to `main`) plus
   the golden fixtures. Document conversion variant: a real minimal single-page
   PDF synthesized with correct xref offsets (validated byte-for-byte by tests)
   and a `golden-expected.md` scaffold to record into. OCR variant (description
   mentions ocr/tesseract): a real 1x1 PNG (bytes written as bytes — a UTF-8
   string write corrupted the 0x89 signature; test-caught) and a
   `golden-expected.json` scenario script encoding the deterministic seed (a
   stable FNV-1a derivative of the behavior id, golden-pinned in tests) and the
   tolerance threshold (`fieldAccuracy >= 0.95`) with the `expected` field map
   null until recorded. The lane runs in NO default tier (`exclude_tags:
   slow`), is gated by `dart test --preset=integration`, and never skips
   silently: an unwired binding or unrecorded golden fails loudly.
5. **CI wiring (remediation 2, "still a gate").** `DartTestYamlWriter` writes
   the tier structure into fresh consuming projects (tags declared, slow
   excluded, integration preset). The repo's `ci.yaml` gains an
   `ffi_golden_lane` job running `dart test --tags ffi` — scoped to the tag
   rather than the whole integration preset, which the `dart_test.yaml` policy
   keeps off CI agents. The job is never vacuously green: sc_022 carries the
   `ffi` tag, and a zero-match tag selection exits 79.
6. **The loop routes ffi honestly.** The row's kind rides into the planner
   (`BehaviorSummary.kind`, resolved by make through the shared
   `TestListReader`): kind `ffi` plans NOTHING and reports `unexpressible`
   naming the wiring path — before the id-prefix dispatch, so a `U<n>` ffi
   behavior can never reach `tdd func` (whose scaffold would refuse the harness
   shape and dead-end the run in a `generation-error`). The run driver's
   existing #625 deferral then handles the rest: phase 1 continues past the
   behavior, phase 2 re-attempts, and the end state names the behavior and the
   manual path. `plan` preserves hand-written ffi rows verbatim through
   re-planning (pre-fix it silently re-homed them as plain unit rows — the RED
   repro captured that destruction), and an ffi row whose traces match a
   spec-derived criterion claims that criterion, suppressing the duplicate.
   gen's staleness auto-regeneration is disabled for ffi harnesses: partial
   wiring (constants edited, seams still throwing) is real work the byte-compare
   would clobber — the same shape as the entity-overwrite hazard (#829).

## What did NOT change

- The generic pair for `acceptance`/`unit` behaviors, the func/entity/CRUD
  pipelines, composition, refactor passes, and verify-red's single-test contract
  are byte-for-byte untouched; kindless planner callers route exactly as before
  (pinned by a regression test).
- `verify_command`, the mutation auditor, and the artifact-registry schema are
  untouched — the registry records the contract pair only; the golden lane is an
  auxiliary surface, surfaced through gen's structured output and JSON verdict.
- Pre-existing master failures (documented in verification.md) and the
  `examples/mcp_demo` format drift are not remediated here (single-purpose PR).
