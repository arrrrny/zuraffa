# Bug Assessment: persistence test harness — Hive CE temp-box lifecycle + corrupted-box recovery

- **Slug**: tdd-persistence-test-harness
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/833
- **Verdict**: valid
- **Severity**: high

> Provenance note: the referenced records were not present on `master` when
> this fix branched (the slug directory did not exist and GitHub issue #833
> was unreachable). This assessment was reconstructed verbatim from the bug
> brief so the fix's audit trail stays complete; it follows the house record
> format (`tdd-entity-orchestration-loop`).

## Report (verbatim or summarized)

Specs 005 (caching), 089 (offline mode), 091, 092 and all cached entities
need real Hive CE behavior under test: TTL expiry, box corruption, registrar
failures. The TDD loop has no persistence harness — no temp-box lifecycle, no
corruption drills, no registrar gate. TTL assertions use real sleeps — the
suite slows at 120-spec scale.

## Symptom

A `zfa tdd gen` test for a persistence-kind behavior (TTL expiry, box
corruption, registrar failure) is generated WITHOUT a Hive temp-box
lifecycle: no per-test box set, no injected clock (TTL assertions would need
real `Future.delayed`/`Future.sleep`), no corruption drill surface, and no
registrar gate — an adapter registration failure would first surface as a
runtime read crash instead of a deterministic init-time red.

## Reproduction

1. Mark a behavior persistence-kind in `specs/<feature>/tdd/test-list.md`
   (the plan marks the behavior).
2. `zfa tdd gen <behavior-id>`.
3. Observe the generated test: it imports only the subject, has no temp-box
   bootstrap/teardown, no `advanceTime` clock, no corruption fixture, no
   registrar gate — a Hive-touching behavior gets a plain function test.

## Suspected Code Paths

- `zfa tdd gen` (`lib/src/plugins/tdd/commands/gen_command.dart`) — writes
  the pair through `BehaviorTestWriter`, which has no persistence shape.
- `TestListReader` (`lib/src/plugins/tdd/services/test_list_reader.dart`) —
  no persistence-kind marker in any accepted row dialect.
- `Behavior` / `BehaviorRow` (`lib/src/plugins/tdd/models/behavior.dart`) —
  carry only `acceptance|unit` kind, no persistence flag.
- Runtime cache (`lib/src/core/cache_policies.dart`) — `TtlCachePolicy`
  reads `DateTime.now()` directly; no clock injection point, so TTL expiry
  can only be asserted with real sleeps.
- No `testing/` surface in the package — nothing offers a temp-box harness,
  corruption fixture, or registrar gate to generated or hand-written tests.

## Root Cause Hypothesis

High confidence: the TDD generation pipeline was built for pure-function and
entity surfaces and never grew a persistence dimension. There is no marker
to carry "this behavior touches Hive" from plan to gen, and the package
ships no harness the generated tests could bootstrap, so persistence tests
would each hand-roll box lifecycle (or sleep through TTL) — at 120-spec
scale that is no harness at all.

## Proposed Remediation

**Preferred**:
1. Test bootstrap rule: a fresh temp-directory box set per test, torn down
   per test — generated into the test by `zfa tdd gen` when the plan marks
   the behavior persistence-kind (`[persistence]` marker in the test-list
   row, parsed through the shared `TestListReader`).
2. Clock injection: a zfa test clock with `advanceTime` — TTL assertions
   advance virtually; no real sleeps in the suite (`TtlCachePolicy` gains an
   optional clock so generated and hand-written tests inject it).
3. Corruption drills: the harness seeds a pre-corrupted box fixture inside
   the temp dir and drives the recovery path (clear + re-fetch per spec edge
   cases) without destroying data outside the temp box.
4. Registrar gate: init-time adapter registration failures surface as a
   deterministic `RegistrarGateError` from bootstrap — a red at init, never
   a runtime read crash (spec 005 US3-AC3).

**Alternatives** (optional):
- Hand-rolled per-test `Directory.systemTemp` + `Hive.init` boilerplate in
  every persistence test — the current implicit workaround; does not scale
  and invites shared-state leaks.
- Real sleeps for TTL — rejected: suite time explodes at 120-spec scale.

**Files likely to change**:
- `lib/src/testing/persistence_test_harness.dart` (new) — harness + clock +
  corruption drill + registrar gate
- `lib/zuraffa.dart` — export the harness surface
- `lib/src/core/cache_policies.dart` — optional clock on `TtlCachePolicy`
- `lib/src/plugins/tdd/models/behavior.dart` — persistence flag
- `lib/src/plugins/tdd/services/test_list_reader.dart` — `[persistence]`
  marker parsing
- `lib/src/plugins/tdd/services/behavior_test_writer.dart` — persistence
  test shape (bootstrap/teardown per test, clock, harness docs)
- `lib/src/plugins/tdd/commands/gen_command.dart` — flag propagation
- `lib/src/plugins/tdd/commands/plan_command.dart` — persistence-kind
  marking when planning
- Test suite

**Tests to add or update**:
- Harness: per-test temp-box lifecycle (fresh set per bootstrap, teardown
  closes + deletes, per-test isolation), clock `advanceTime` (virtual, no
  real time), corruption drill (pre-corrupted fixture → recovery clears +
  re-fetches; data outside the temp box untouched), registrar gate
  (registration failure → deterministic init-time red; missing adapter
  surfaced at bootstrap)
- `TtlCachePolicy` expires virtually under the injected clock (no sleep)
- Reader: `[persistence]` marker parsed + stripped across dialects; absent
  marker leaves the row untouched
- Writer: persistence-kind behavior → harness-backed test (bootstrap per
  test, `advanceTime`, no real sleeps); non-persistence behavior → byte-for-
  byte unchanged shape
- Plan: persistence-worded criteria are marked; others are not

## Risks & Considerations

- Temp-box lifecycle must be per-test, never shared across tests.
- The test clock must not affect other test features — it is an instance the
  owning test controls; nothing global mutates.
- Corruption drills must not destroy data outside the temp box — all drill
  writes stay inside the harness-owned temp dir.
- Registrar gate must surface init failures, not runtime crashes — gate
  checks run inside `bootstrap()`, before any test body executes.
- 5 specs directly affected (005, 006, 089, 091, 092) plus all cached
  entities.
- Apply the MINIMAL change; one PR for this bug only.

## Open Questions

- None — the remediation is fully specified by the brief.
