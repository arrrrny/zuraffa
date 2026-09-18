# TDD test list — Issue #1685 review bot snippet uses non-existent `Directory.deleteRecursively`

Spec: `.specify/specs/1685-review-bot-snippet-compilable/spec.md`

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1685-G1a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `tempDirCleanup` renders the exact issue-workaround shape — `Directory.systemTemp.createTempSync` + `addTearDown(() => tmp.deleteSync(recursive: true))` — and contains no `deleteRecursively` | issue #1685 (fix criterion 1, SC-1) | RED → GREEN |
| U-1685-G1b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | NO template in the catalog references any deny-listed (verified non-existent) API member — the catalog-wide invariant | fix criterion 3 (audit), SC-1 | RED → GREEN |
| U-1685-G2a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | static deny-list scan rejects the HISTORICAL snippet verbatim (`addTearDown(_tmp.deleteRecursively)`, inline comment id 4023967373) with `non_existent_api` + the compilable replacement | fix criterion 2 (compile-check), SC-2 | RED → GREEN |
| U-1685-G2b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | REAL analyzer compile check rejects the historical snippet — `undefined_getter`, the issue's exact diagnostic class | fix criterion 2 (compile-check), SC-2 | RED → GREEN |
| U-1685-G2c | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | the FIXED render passes the REAL analyzer compile check with zero errors (in-process resolve over a wrapper file in the gitignored `build/` scratch) | fix criterion 1, SC-2 | RED → GREEN |
| U-1685-G2d | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `validate()` combines both layers — a scan hit short-circuits before the analyzer runs | gate contract, SC-2 | RED → GREEN |
| U-1685-G3a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `postableSnippet` — the ONLY sanctioned posting path — returns compiled-verified code | fix criterion 2 (never posted un-verified), SC-2 | RED → GREEN |
| U-1685-G3b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | unknown template ids throw [ArgumentError] on both `render` and `postableSnippet` — no ad-hoc template fallback | gate soundness | RED → GREEN |
| U-1685-G4 | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | two CONCURRENT `compileCheck` runs both pass — each owns a per-run scratch subdirectory under `build/zuraffa_snippet_checks/`, so no run deletes or overwrites another's wrapper mid-resolve (PR #1703 review fix) | review finding: shared-scratch race | GREEN |
| U-1685-P1 | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | unit | the posting transport extracts exactly the ```dart fenced blocks from a body (prose/`json` fences ignored) | review finding: gate has no production caller | GREEN |
| U-1685-P2 | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | unit | a body whose dart block is the HISTORICAL misfire snippet is BLOCKED before any network request — the gate is load-bearing at the transport | review finding: gate has no production caller | GREEN |
| U-1685-P3 | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | unit | a body with a compilable dart block posts (REAL analyzer resolve in the gate) | review finding: gate has no production caller | GREEN |
| U-1685-P4 | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | unit | `postSnippetSuggestion` — the sanctioned catalog path — assembles via `ReviewSnippets.postableSnippet` and posts the validated code | review finding: postableSnippet needs a non-test caller | GREEN |
| U-1685-P5 | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | unit | `postSnippetSuggestion` refuses an unknown template id with no request sent | gate soundness at the transport | GREEN |

Guard pins (pre-existing, unchanged and green against the fix — posting
semantics untouched):

| id | suite | description |
| -- | ----- | ----------- |
| U12/U13 (spec 070) | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | the PR comment poster — URL/token/500-fallback/dry-run contract, unmodified |
| verdict renderer | test/plugins/tdd/services/ci_referee/verdict_comment_test.dart | the verdict comment markdown contract, unmodified |
# TDD test list — SPEC 1693: mock cert digest is format-canonical (no re-cert after phase-2 format)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| G1 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | `dart format`-only drift after certification (bytes change, mtime moves, declaration does not) → the gate reads `certified` — a second sandbox certification is NOT demanded (the #1693 bug; pre-fix this read `stale`) | issue #1693 constraint 1, SC-1 | RED → GREEN |
| G2 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | a real entity edit after certification (new field, different AST) → `stale` with the exact fix command and the canonical reason prefix | issue #1693 constraint 2, SC-2 | RED → GREEN |
| G3 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | an unparseable entity source with a recorded digest → `stale` (what cannot be canonicalized cannot be what was certified) | constraint 2 (soundness) | GREEN (mtime-equivalent pre-fix) |
| G4 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | pre-1693 receipts (no `entity_digest`) keep the mtime freshness semantics — entity touched after the receipt → `stale`, same reason contract | SC-3 | GREEN (guard, passes pre- and post-fix) |
| G4b | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | pre-1693 receipts keep mtime freshness — receipt newer than the entity → `certified` | SC-3 | GREEN (guard, passes pre- and post-fix) |
| G5 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | the digest overrides a lying-fresh mtime — a receipt re-touched after a real edit still refuses (semantic drift is never waived even when mtimes lie) | constraint 2 (strongest form) | RED → GREEN |
| G6 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `entity_digest` and the `entity_digest_style` that produced it roundtrip through toJson/fromJson | SC-4, review finding 2 | RED (compile) → GREEN |
| G6b | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | a receipt without an entity digest omits the JSON key — pre-1693 receipts stay byte-stable (no identity key either: it is meaningless without the digest it produced) | SC-4 (legacy byte stability) | RED (compile) → GREEN |
| G7 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `fromRun` records the digest and its canonicalizer identity when given, omits both when null | SC-4, review finding 2 | RED (compile) → GREEN |
| G8 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `MockCertifier.certify` records the format-canonical digest of the entity source via the lib-side helper AND the running `canonicalizerId`; the written receipt carries both keys | SC-4, constraint 4, review finding 2 | RED (compile) → GREEN |
| G8b | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `certify` without an entity file records NO digest (honest absence — the gate falls back to mtime for that receipt), and no canonicalizer identity either | SC-4 (honest absence) | RED (compile) → GREEN |
| G9 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | an entity OUTSIDE `<entities>/<snake>/<snake>.dart` still gets a digest, and the gate compares against that same file — format-only drift at the nested path reads `certified`, a real edit at the nested path still reads `stale` | review finding 1 (one resolver for both sides) | RED → GREEN |
| G10 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | a digest recorded by ANOTHER canonicalizer (or by none at all) is not compared: a bare `dart pub upgrade` does not flip the project `stale`, and the fallback is the full mtime leg — a real format rewrite after the bump still refuses | review finding 2 (mass re-certification) | RED → GREEN |
| G12 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | the digest helper is TOTAL: a formatter failure that is NOT a `FormatterException` (a `dart_style` `_TypeError`, deterministic on 3.1.13) yields `null` instead of escaping as a crash out of the preflight | review finding 3 (verdict must not become a crash) | RED → GREEN |
| G12b | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | a null (unresolved) entity file yields `null`, not a throw — the recording call site stays a one-expression digest | review finding 1 (nullable helper) | RED → GREEN |
| W1 | test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart | unit | the `zfa tdd run` preflight (`RunEngineCommand.checkFeature`, the task's `UserSession` repro) certifies after phase-2 format-only drift — the pin writes the `entity_digest_style` the certifier records, so the digest branch is the one under test | issue repro, SC-1 | GREEN (post-fix wiring pin) |
| W2 | test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart | unit | the preflight still refuses after a real entity edit — `blockedEntity: UserSession`, stale reason, exact fix | issue repro, SC-2 | GREEN (post-fix wiring pin) |

## Red evidence (pre-fix, this session, base a9329746)

- Behavioral red — the gate file compiles against the pre-fix tree
  (hand-written receipt JSON with `entity_digest`; the pre-fix loader
  ignores the unknown key):
  `dart test test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart`
  → `00:00 +4 -2: Some tests failed.`
  - G1 FAILED for exactly the issue's reason: format-only drift read as
    `stale` (mtime, digest ignored).
  - G5 FAILED for exactly the digest-first claim: a lying-fresh mtime
    was accepted.
  - G2/G3/G4/G4b passed — the guards that must survive the fix.
- New-seam red — the receipt/certifier file fails to LOAD pre-fix:
  `Error: The getter 'entityDigest' isn't defined for the type
  'MockCertReceipt'` (+ `format_canonical_digest.dart` unresolved) —
  the honest first red for a NEW seam (spec 1001/1664 convention).

Both recorded verbatim in
`.specify/specs/1685-review-bot-snippet-compilable/red-evidence.md`:

1. **The bug's red** — the bot's snippet applied VERBATIM inside the
   standard wrapper:
   `dart analyze build/1685_repro_snippet_test.dart` →
   `error - The getter 'deleteRecursively' isn't defined for the type 'Directory'. - undefined_getter`
   (the issue's exact error, reproduced in this session on Dart 3.13.4).
2. **The new seam's honest red** — the regression suite pre-implementation:
   `dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
   → load failure (`No such file or directory` for
   `review_snippets.dart` / `snippet_compile_check.dart`) — the
   compile-error red proving the seam (catalog + validation gate) did not
   exist.
## Green evidence (post-fix, this session)

- Both spec suites: `dart test
  test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart
  test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart`
  → `00:00 +11: All tests passed!`
- Wiring pins: `dart test
  test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart`
  → `00:00 +2: All tests passed!`
- Mutation audit (`mutation-test-1693.xml`, scoped to the spec-1693
  freshness lines of `cert_registry.dart` + `format_canonical_digest.dart`,
  command `bash tools/run-1693-mutation-tests.sh`):
  → `Total tests: 16, Undetected Mutations: 0 (0.00%), Success: true`.
  The first pass left 2 survivors — both character-level mutations of the
  stale-reason string literal (`mock-cert` → `mock+cert`); G2/G4 were
  strengthened to pin the reason prefix and the audit re-ran clean.

## Follow-up round — review findings on the format-canonical basis

The review of PR #1700 accepted the direction and flagged four boundaries
of the new basis (1 major, 2 medium, 1 minor). Applied on top of
`76a00027`; see `verification.md` §"Follow-up round" for the full mapping.

### New red evidence (post-#1700 round, base 76a00027)

Each new behavior was proved red against the pre-fix tree of this round,
one finding at a time:

`dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
→ `00:11 +8: All tests passed!` (8/8 — U-1685-G1a/G1b, G2a/G2b/G2c/G2d,
G3a/G3b).

## Review-fix evidence (PR #1703 follow-up, this session)

Review findings applied: the gate is now load-bearing (poster transport
validates every ```dart block, fail-closed; suggestions sourced via
`ReviewSnippets.postableSnippet`) and compile checks own per-run scratch
subdirectories (no concurrent delete/overwrite race).

```
$ dart test test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart \
    test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart
→ 01:02 +17: All tests passed!   (9 spec_1685 incl. U-1685-G4, 8 poster incl. U-1685-P1..P5)
$ dart test test/plugins/tdd/services/ci_referee/
→ 00:29 +40: All tests passed!  (ci_referee suites green — guard pins intact)
$ dart analyze <touched files> → No issues found!
```
- **G9 (finding 1)** — with the certifier back on `entityFileRel` alone:
  `G9 … [E]  Expected: 'b65aa851…'  Actual: <null>` — no digest recorded
  for the nested layout, which hands the entity straight back to the
  mtime leg.
- **G10 (finding 2)** — with the gate's condition back to
  `recordedDigest != null && recordedDigest.isNotEmpty`:
  `Expected: CertRegistryStatus:<stale>  Actual: <certified>` — the
  digest was compared across engines, so the mismatched id still counted
  as a verdict.
- **G12 (finding 3)** — with the catch back to `on FormatterException`:
  `Expected: return normally  Actual: threw _TypeError:<Null check
  operator used on a null value>` — the formatter's failure escaped the
  helper and the preflight.

### Green evidence (this round)

- Both spec suites (`+7` gate, `+8` receipt):
  → `00:07 +15: All tests passed!`
- Mapped scope (the certification dir, `cert_registry_test.dart`, both
  `spec_1693_*` wiring pins, `test/engine/mock_certifier_test.dart`):
  → `00:20 +59: All tests passed!`
- `dart analyze` on `lib/src/plugins/mock/certification` +
  `test/plugins/mock/certification` → `No issues found!`
- `dart format --set-exit-if-changed lib test` → `0 changed`, exit 0.
- Mutation audit re-run on the moved whitelist (see `verification.md`
  §3): `Total tests: 19, Undetected Mutations: 0 (0.00%), Success: true`
  — the identity-check mutants are killed by G1/G5 on one side and G10
  on the other.
- The `canonicalizerId` probe source is a `const` in the same file as the
  helper, so it cannot ship unparseable without failing every suite above.

## Guard pins (pre-existing, unchanged and green against the fix)

| id | suite | description |
| -- | ----- | ----------- |
| 1110 | test/plugins/mock/cert_registry_test.dart | the spec-1110 existence/freshness/reference vocabulary (legacy mtime receipts) |
| 1001 | test/plugins/mock/certification/mock_cert_receipt_test.dart | the receipt document contract |
| 1110-fixture | test/plugins/mock/certification/mock_cert_registry_test.dart | the registry fixture behaviors |
| 1002 | test/engine/mock_certifier_test.dart | the engine-side live certification (shares the gate read side) |
| preflight | test/plugins/tdd/commands/run_engine_command_test.dart | the spec-1001 run preflight wiring |
