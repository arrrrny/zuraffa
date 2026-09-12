# PR — fix(1512): acceptance lane — thread args, assert declared outcomes, real make surface

- **URL**: https://github.com/arrrrny/zuraffa/pull/1522
- **Branch**: `fix/1512-acceptance-vacuous-composition` → `master`
- **Closes**: #1512
- **Commits**:
  - `c20dd406` WIP: red — bug 1512 acceptance vacuous composition (7 root-cause pins failing for the right reasons)
  - `7d93b096` fix(1512): acceptance lane — thread args, assert declared outcomes, real make surface
- **Verification**: `tdd/verification.md` (this repo root) — PASS: analyze clean, bug suite red→green, chunked sweep ~2,435 tests green, no new failures.
- **Round-2 review fixes (2026-09-11)**: the review found the writer half did
  not ship — no acceptance behaviour ever receives a `contractShape`
  (`gen_command.dart` gates it to `BehaviorKind.unit`) and the paired
  acceptance subject is a parameterless `void <target>()` scenario runner, so
  the "thread declared args / return the declared result" branch was
  unreachable in production and would not compile against the pair `gen`
  emits. Applied the reviewed option (b): the unreachable acceptance branch
  is REMOVED (the shape is unit-lane only and is inert for acceptance), the
  fallback's marker is replaced by the distinct
  `acceptanceFallbackGuardToken` (marker absence keeps the run driver's
  honest `stopped_at=<id>:make` classification), and branch 3b no longer
  consults the capitalised-trace extractor (only explicit prose signals may
  drive `entity create`). The suite was rewritten to drive the real path and
  now includes a slow `dart test` compile pin over the emitted test+subject
  pair. **The PR title/body's first bullet ("thread args, assert declared
  outcomes") describes the removed branch, not the shipped behaviour** — the
  shipped surface is the real `make` surface (branch 3b) plus the honest
  fallback naming; the acceptance row's declared outcome is asserted through
  the composition lane.

