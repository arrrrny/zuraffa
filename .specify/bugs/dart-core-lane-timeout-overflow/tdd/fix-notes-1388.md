# Fix Notes: bug_1388 born-red repair

## Why the suite was red on master

`test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart` entered
master via a single `stash` commit and failed on every recent CI run
(`PathNotFoundException: …/test/a1_test.dart`, then a stale-header assertion).
Three independent defects, all test-side:

1. **Wrong path read** — the suite registers behavior A1 at the namespaced
   `test/tdd/<feature>/a1_test.dart` (the ownership preflight compares the
   record against exactly this form) but then read the helper's flat
   `testPathOf('A1')` default (`test/a1_test.dart`). gen correctly wrote the
   namespaced path; the assertion read a file that never existed.
2. **Progressed-subject seed** — the fixture seeded the subject as
   `// GENERATED STUB …\n// behavior_id: A1\n` with no `UnimplementedError`.
   gen's staleness mirror treats a subject past the stub stage as PROGRESSED
   work it must never clobber (`gen_command.dart` "A progressed artifact is
   never clobbered"), so the regeneration under test could never fire —
   verdict stayed `reused`.
3. **No declared surface** — the drifted traces cell
   (`FR-007, adaptive_layouts`) resolved nothing because the fixture declared
   no spec; the render stayed guard-only and the #1320 contract-drift
   classification (`contractShape != null && contentIsVacuousGreen(onDisk)`)
   could never be true. B2's "no drift" premise was equally vacuous — both
   rows silently got `reused` from the progressed-subject guard.

## The repair (no gen semantics changed)

- Seed the pre-drift pair as gen actually renders it: a guard-only test
  (`expect(result, isNot(isA<UnimplementedError>()))` — vacuous-green by the
  content backstop) plus a faithful stub subject that throws
  `UnimplementedError`.
- Declare `adaptive_layouts` in the fixture's `spec.md` Layer Contracts
  (`**Function**: - \`adaptive_layouts\`: \`resolve(double width) -> String\``)
  so the drifted traces cell resolves a real declared shape.
- Read the registered namespaced path; B2 becomes the honest no-drift guard:
  gen once (renders + arms the record's reuse fingerprint), gen again with
  nothing changed → byte-equality short-circuit → reused untouched, no
  `traces cell gained` note.

## Evidence

- Pre-fix on this branch: B1 `PathNotFoundException` / reused verdict
  (captured in the session debug runs).
- Post-fix: `2/2` green — B1 asserts `verdict=regenerated` +
  `traces cell gained a contract token` + the test file carrying
  `adaptive_layouts`; B2 asserts the silent idempotent reuse.
