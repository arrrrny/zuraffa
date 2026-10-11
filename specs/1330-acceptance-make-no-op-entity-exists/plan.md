**Template Version**: `zuraffa-1.0`

# Plan: 1330-acceptance-make-no-op-entity-exists

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.13 / published deps);
  no Flutter SDK dependency on this package's own test path.
- **Feature surface** (issue #1330 hard constraint: ONLY the
  `zfa tdd make` fallback path when the inner `zfa make <Row>` returns
  no-op; the core engine cycle, the entity scaffold, the plugin system
  (bug #826), and the verify gate are untouched):
  - `lib/src/plugins/tdd/commands/make_command.dart` — the bug-#826
    no-op pre-flight (lines ~932-961) and its private helpers
    (`_bareMakeName`, `_innerMakePlanIsEmpty`). Today the pre-flight
    aborts the WHOLE make (`verdict: no-op`, exit 1) whenever the
    effective plan's FIRST step is a bare `make <Row>` whose mirrored
    plugin plan is empty — the exact shape the #829 entity gate produces
    for a sibling acceptance behavior (`[make E, tdd wire A1 --entity E,
    --feature F, build]`). ADDS: a subject-edit fallback arm — when the
    remaining steps still carry a subject-edit step (`tdd wire` /
    `tdd func`), drop the no-op make step, print the fallback lines, and
    continue into the pipeline; the existing post-pipeline verification
    (target re-run, #737/#942 build tolerance, #731 suite guard) then
    grades the real outcome. Plans without a subject-edit step keep the
    #826 verdict verbatim.
- **Why this is the whole fix**: the driver's phase-2 wedge is a
  CONSEQUENCE of the make's no-op verdict. With the fallback applied the
  make reports `green` (wire turned the subject green) or an honest
  failure (`generation-error`) — never `no-op` — so the deferral arm
  (`run_driver_core.dart:1352`, `unexpressible|no-op`) never engages for
  the entity-exists case and phase 2 never re-plans identical steps. The
  driver itself needs zero changes (FR-005).
- **Entity reuse**: the fallback only REMOVES a plan step; the #829 gate
  already dropped `entity create` for the existing entity, so no code
  path in the fallback can touch the entity file (FR-003).

## Key decisions

- **D1 — drop-and-continue, not spawn-and-continue.** The #826 remediation
  exists precisely to avoid spawning the analyzer-heavy `zfa make` child
  that would print "No active plugins to run." and exit 0. Letting the
  child run (the entity-absent accidental behavior) would re-introduce the
  wasteful spawn; dropping the step keeps the pre-flight's cheap in-process
  mirror AND unblocks the subject edit.
- **D2 — the fallback requires a subject-edit step in the REMAINING plan.**
  `tdd wire` / `tdd func` are the two subject-edit surfaces (the commands
  that replaced the stub bodies of A1/A3 in the issue repro). Plans whose
  remaining steps carry neither (e.g. the non-acceptance CRUD shape
  `[make E, build]`) have no in-band subject edit to fall back to — they
  keep the honest #826 verdict + remedy line (fail-closed, FR-004).
- **D3 — the fallback prints, never silently re-plans.** Same contract as
  the #829 gate (`already exists — reuse`, printed): the fallback lines
  name the resolution, the entity reuse, and the dropped step, greppable
  via `issue #1330`.
- **D4 — no driver change, no new outcome token.** The make's existing
  outcome taxonomy already covers the post-fallback realities (`green`,
  `generation-error`, `regression`, ...). A new token would leak into the
  driver, the corpus ledger, and receipts — all unchanged here.

## Risks / notes

- In-process fast tests without `--zfa-bin` reach the pipeline after the
  fallback; the pipeline's entrypoint resolution fails fast there (the
  test kernel is not a CLI — verified `dart <test-kernel> tdd wire ...`
  errors immediately), grading `generation-error`. The fast tests assert
  the DECISION (fallback lines, no `verdict: no-op`, entity untouched)
  and tolerate the pipeline's graded outcome; the real green is proven by
  the e2e tests (SC-2/SC-3).
- The e2e tests follow the sc_017/sc_021 provisioning (real zorphy +
  build_runner deps, pure-exec forwarder). The run driver passes
  `--zfa-bin <forwarder>` as its ENTRY, so the spawned make children run
  WITHOUT a `--zfa-bin` flag — the pre-flight is active inside them and
  the pipeline resolves via `Platform.script` to the real `bin/zfa.dart`.
