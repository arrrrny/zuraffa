# Test List: 0806-zfa-replay

Format: `[status] BEHAVIOR-ID — one-line behavior (traces to SC/FR)`.
Statuses: PENDING → RED → GREEN → DONE. Tier: fast (unit) / integration (scenario).

## Outer acceptance behaviors (drive the CLI surface end-to-end)

- [DONE] A1 [integration] A recorded-elsewhere history (the todo example's
  shape: `<other-root>/./…` test paths, `<other-dart> <other-zfa>` gen steps,
  anchored registry) replays its FULL recorded history clean — exit 0,
  `result=clean`, and no recorded-root prefix survives into any spawned
  argument. (SC1, FR-001..FR-005; US1)
- [DONE] A2 [integration] An injected mutation into a replayed step of a
  re-anchored history is caught with the step named — gen drift names the
  project-relative path; exit 1 `result=divergent`. (SC2; US3/4)
- [DONE] A3 [fast] Same-machine histories replay byte-identically to 066 —
  the whole 066 suite passes unmodified. (SC3, FR-007; US2)

## Inner unit behaviors (one proven fact each)

- [DONE] U1 [fast] detectRecordedRoot: one consistent `<root>/./` anchor →
  that root; zero anchors → null; two conflicting roots → null. (FR-001)
- [DONE] U2 [fast] verifyIntegrity re-anchors a missing-locally red test
  path through `recordedRoot` into the project root; still-missing →
  `red-missing-test-artifact: <recorded-path>` unchanged; locally-existing
  path → untouched (same-machine first). (FR-002)
- [DONE] U3 [fast] reAnchorEntrypoint: `--zfa-bin` wins over any zfa
  entrypoint form; missing recorded dart → running dart; missing zfa →
  running entrypoint; resolvable pair unchanged; nothing resolvable →
  runner-error exit. (FR-004)
- [DONE] U4 [fast] reAnchorCommand strips every `<root>/./` occurrence to
  the relative tail (sandbox cwd), inside and outside quotes. (FR-003)
- [DONE] U5 [fast] ReplaySandbox rewrites `<root>/./` → `<sandbox>/./` in
  `specs/<feature>/tdd/*.json` and seeds build.yaml / dart_test.yaml when
  present; anchor-less registries copy verbatim. (FR-005)
- [DONE] U6 [fast] `zfa entity create -n X` with the target entity file
  already on disk exits 0 and leaves the file's bytes untouched
  (convergent fixed point). (FR-006)
- [DONE] U7 [fast] `zfa tdd func <id>` on an implemented subject whose
  stale doc comment mentions `UnimplementedError` exits 0
  `already-implemented`; a subject with a genuine unrecognized
  `throw UnimplementedError(` still exits 1 runner-error. (FR-006)

## Live delivery evidence (not a dart test; recorded in verification.md)

- [DONE] L1 LIVE `zfa replay examples/todo_tdd/specs/001-todo-app/tdd/cycle-log.md`
  → exit 0 `result=clean replayed=9 skipped=1 diverged=0`. (SC4)
- [DONE] L2 LIVE injected mutation into the todo example's generated tree
  before replay → caught, gen drift path named, exit 1; tree restored after.
  (SC4)
