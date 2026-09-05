---
feature: 1009-realize-mock-firestore-differential
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: spec/1009-realize-mock-firestore-differential working tree (branch spec/1009-realize-mock-firestore-differential, pre-commit)
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 4/4 caught # deliberate-mutant sample; scope: realize_mock_command.dart, tier2_mock_provider.dart, fake_firebase_firestore.dart
mutants_survived: 0
suite: fast tier chunked 75/75 chunks (71 PASS, 4 by-design slow-tier SKIP, 0 FAIL); focused new-code 44/44; analyze 0 errors; format 0 diffs
---

# TDD Verification: realize-mock --against=firestore differential gate (spec 1009, closes #1009)

**Verdict: PASS.** The red phase is recorded before the green (the
command-not-found reproduction ran against the pre-implementation tree —
exit 64, `Could not find an option named "--against"`, captured in this
session and chained into the feature's cycle log), the implementation
landed through the same red → green loop the 913 realize work used, the
full fast-tier suite is green chunked 75/75 with zero failures, all four
sampled deliberate mutants were killed with byte-exact restoration
re-verified green, and every success criterion of the issue is proved by a
real run through the public CLI surface — not by an assertion about a
double. No HIGH test smell was found. The evidence weaknesses that remain
are disclosed below; none of them touches the issue's exit criteria.

**Engine path disclosure (Step 0):** `/speckit.tdd.verify` ran its engine
detection — `zfa --version` succeeds (v6.1.0) but `.zfa.json` does not
exist in the repo root, so the audit took the documented `ZFA_MISSING`
fallback path (the LLM-guided rubric audit), exactly as the specs/067,
068, and 069 verifications did. No `zfa tdd verify` mutation gate ran;
the mutation evidence below is deliberate-mutant sampling per the
profile's documented fallback.

## Test-first evidence

The cycle log at
`specs/1009-realize-mock-firestore-differential/tdd/cycle-log.md` carries
two schema-1 hash-chained entries written by the repo's own
`EraTaggedLog` machinery: the red entry (kind `red`, era MOCKED, exit 64,
the real `Could not find an option named "--against"` transcript from the
pre-implementation tree) and the green entry (kind `green`, era MOCKED,
exit 0, the certified production run's transcript). The chain hash covers
the era-aware payload, so the pair is tamper-evident, and the green entry
chains onto the red entry's hash — the order is provable, not asserted.

The red reproduction predates every implementation file in this PR: at
the moment it ran, `rg -l "Tier2MockProvider|FakeFirebaseFirestore"` over
`lib/` returned nothing and `zfa tdd realize-mock` exited 64 on the
unregistered verb.

## What the tests actually assert (rubric stage 2 — read as written)

- `realize_mock_command_test.dart` drives the **public CLI surface
  in-process** (a `CommandRunner` with the real `RealizeMockCommand`,
  only the process boundaries injected — the suite-runner subprocess and
  the per-case provider factory, the realize command's own test pattern).
  It asserts the exit code, the machine summary line, the receipt file's
  JSON shape, the per-method records' contents, the cycle-log evidence,
  the `zfa proof check` integration (a real `ProofChecker.check()` over
  the fixture root — parse counted, findings empty, `ok: true`), and the
  fail-closed classes (usage, blocked, tier1-red, runner-error).
- `tier2_mock_provider_test.dart` asserts the adapter's routing through
  the REAL fake Firestore (seed → typed store → snapshot read), including
  the int-vs-double type-fidelity case and the named-method errors.
- `fake_firebase_firestore_test.dart` asserts the typed-value codec's
  round-trip, the `integerValue`-vs-`doubleValue` distinction at the wire
  level, and the collection/document semantics (replace-on-set,
  idempotent delete, document-id ordering, collection isolation).
- No test asserts a mock's configuration back to itself: the Tier-2 side
  under test is the real provider over the real fake store; the injected
  fakes only replace process spawns (the same boundary the realize tests
  inject).

## Mutation evidence (rubric stage 3)

Four deliberate mutants, each applied to the real source, each run
against the focused fast-tier targets, each restored byte-exactly and the
suite re-verified green (44/44):

| mutant                              | change                                                        | result |
| ----------------------------------- | ------------------------------------------------------------- | ------ |
| M1-diff-inverted                    | per-method diff ternary inverted (`none` ↔ `mismatch`)         | KILLED |
| M2-integer-decoded-as-double        | codec decodes `integerValue` as `double`                       | KILLED |
| M3-list-route-removed               | list verbs emptied — `getAll*` falls off the routing surface   | KILLED |
| M4-verdict-hardcoded                | receipt verdict hardcoded `certified`                          | KILLED |

M2 is the wrong-type gate's own teeth: with it, a genuine int/double
divergence through the Firestore-shaped store could not surface. The
tests caught every sampled mutant, including the two (M1, M4) that only
lie in the gate's verdict — the exact class of bug a green-suite-only
audit would miss.

## Acceptance-criteria coverage (rubric stage 4)

Every exit criterion of issue #1009 reached through the real entry point
in this session, artifacts retained:

- **SC-1** `zfa tdd realize-mock Login --against=firestore` exits 0 with
  a clean receipt — PROVED end-to-end on a scratch project (real CLI,
  real `dart test` subprocess running the Tier-1 contract file, real
  Tier2MockProvider): exit 0, `verdict: certified`, 3/3 methods
  `diff: none`, receipt at `.zfa/receipts/realize.Login.firestore.receipt.json`
  with the per-method `{method, tier1_result, tier2_result, diff}`
  records. Also pinned by the in-process SC-1 test.
- **SC-2** a deliberately divergent method (Tier-2 adapter returns the
  wrong type) causes exit 1 with the mismatched method named — PROVED
  twice: through an injected wrong-typed adapter (string `'42'` vs int
  `42`, test SC-2) and through the genuine Firestore type semantics
  (seed `42.0` vs oracle `42`, test SC-2b and the end-to-end run: exit 1,
  `method getById: tier1=...{"attempts":42} tier2=...{"attempts":42.0}
  — the Tier-2 adapter diverged (value or type)`).
- **SC-3** the receipt is machine-readable and parseable by
  `zfa proof check` — PROVED by a real `zfa proof check` run on the
  scratch project: `Verified 0 artifact(s) from 1 receipt(s)` /
  `0 finding(s) — OK`, exit 0; and by the in-process SC-3 test asserting
  `ReceiptStore.loadAll()` parses the document as a `proof.v1`
  generation receipt and `ProofChecker.check()` yields zero findings.

## Suite health (rubric stage 5)

- Fast tier, chunked per `tools/run_tests_chunked.sh`'s chunk list:
  **75/75 chunks — 71 PASS, 4 SKIP (by-design slow-tier folders), 0
  FAIL.** The four SKIPs carry only benchmark/integration/property-tagged
  tests the fast suite excludes by design (verified by the runner's
  "No tests ran" class).
- Focused new-code suite: 44/44 green (`test/plugins/tdd/services/
  tier2_firestore/` + `realize_mock_command_test.dart`), ~4s.
- `dart analyze lib test --no-fatal-warnings`: **0 errors** (baseline on
  the pre-change tree: also 0 — no new diagnostics).
- `dart format .`: **0 remaining diffs**; the format pass touched only
  the five new files of this spec.
- Determinism: the provider is seeded per case (state isolation), the
  collection listing is document-id ordered, and the comparison
  canonicalizes key order — no time-, locale-, or map-order-sensitive
  assertion exists in the new tests.

## Honest gaps

- The mutation evidence is a 4-mutant deliberate sample (the documented
  fallback when the deterministic engine gate is unavailable), not the
  full mutation_test pass `zfa tdd verify` would run on a
  zuraffa-wired target project. The sample was aimed at the two verdict
  paths (comparison, receipt verdict), the type-fidelity codec, and the
  routing surface — the classes where a silent lie would be worst.
- The Tier-1 oracle side is exercised through recorded `mockOutput`
  fixtures (the primary #832 convention) and an injected tier-1 driver
  in tests; the production tier-1 driver fallback path
  (`tool/realize_driver.dart --binding tier1` subprocess) shares its
  protocol with the realize command's driver but was not exercised
  end-to-end against a real project-owned driver script in this session —
  no such driver exists in the scratch project, and the fail-closed
  behavior when it is missing is pinned by the runner-error test.
- No `--against` target beyond `firestore` exists (the issue names
  exactly one); the allow-list enforces that today's misfires name the
  supported values rather than guessing.
