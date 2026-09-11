# Verification: 1391-realize-mock-skip-foreign-fixtures (issue #1391)

**Verdict: PASSED** — every new behavior test-first (red certified before
implementation), every spec success criterion proved by an executed test,
3/3 targeted mutants killed, the issue #1391 repro driven END-TO-END
through the real CLI (`dart run bin/zfa.dart tdd realize-mock`) to exit 0
`result=certified` with the #832 artifacts in place.

## Test-first evidence

The red phase ran BEFORE any implementation existed (see
`tdd/cycle-log.md`, cycle `1391-realize-mock-skip-foreign-fixtures (red)`):

| Test | Red evidence |
| --- | --- |
| A1 (#1391 repro) | `Expected: contains 'result=certified'` / `Actual: 'fixture manifest is not a realize-diff.v1 document (schema, input.op missing) … result=runner-error'` — the issue's exact crash signature |
| A2a (string-schema foreign) | crashed `result=runner-error` on the foreign document; no `skipped foreign.json (schema world-v2)` line existed |
| A2b (schema-less document) | crashed `result=runner-error`; no `schema unknown` skip existed |
| A2c (unparseable .json) | crashed `result=runner-error`; broken JSON had no skip path |
| A3 (foreign-only dir) | `Expected: contains 'result=blocked'` / `Actual: 'result=runner-error'` — the crash this fix removes |
| A4, A5 | backward-compat / fail-closed PINS — green before and after the change (exactly the two behaviors that must NOT change) |

## Green evidence (final pass)

| Suite | Result | Command |
| --- | --- | --- |
| new behaviors (A1, A2a-c, A3, pins A4, A5) | 7 passed | `dart test test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart` |
| pre-existing realize-mock acceptance (SC-1..SC-3, A-H) | 10 passed | `dart test test/plugins/tdd/commands/realize_mock_command_test.dart` |
| pre-existing #1367 mock-cert fallback | 6 passed | `dart test test/plugins/tdd/commands/bug_1367_realize_mock_cert_fallback_test.dart` |
| combined scoped run | **23 passed** | all three files in one `dart test` invocation |
| `dart analyze` (both changed .dart files) | No issues found | `dart analyze lib/src/plugins/tdd/commands/realize_mock_command.dart test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart` |
| `dart format` (both changed .dart files) | 0 changed | `dart format` + `git diff --stat` shows only the intended production diff |

Scope discipline (cloud-agent protocol): only the changed-file suites were
run — the full repo suite (the ~6.5 GB kernel-cache build) was NOT run.
Kernel caches were cleaned pre/post (`rm -rf .dart_tool/test/`).
Pre-existing format drift exists in 2 files this change does not touch
(`example/test/tdd/004-login-ui/u1_test.dart`,
`tool/generate_openwiki_cli_docs.dart`) — flagged, not fixed (one PR per
issue; out of scope).

## Mutation evidence (targeted mutants on the changed code, 3/3 killed)

| Mutant | Change | Killed by | Result |
| --- | --- | --- | --- |
| M1 | skip condition inverted (`!=` → `==`): own-schema docs skipped, foreign docs validated | all 7 (A1, A2a-c, A3, A4, A5) — `+0 -7` | FAILED under mutant (killed), green after restore |
| M2 | zero-cases guard neutralized (`records.isEmpty` → `records.length < 0`) | A3 only (`+6 -1`) — exactly the guard's subject | FAILED under mutant (killed), green after restore |
| M3 | skip made silent (log line removed) | A1 + A2a + A2b + A2c (`+3 -4`) — the skip-visibility assertions | FAILED under mutant (killed), green after restore |

Mutation scope: the production surface this feature changes (the scan's
schema-classification condition, the post-scan zero-cases guard, the skip
log line). The full-package MutationAuditor was not run: it requires the
full-suite preflight the cloud-agent protocol forbids; the targeted
mutants audit exactly the changed surface.

## End-to-end demo (the issue #1391 repro, real CLI)

Scratch project (`/home/z/my-project/scratch/1391-demo`, script
`scripts/1391_e2e_demo.sh` in the worklog sense — not committed) whose
`specs/1391-demo-login/tdd/fixtures/` holds the 3 committed
realize-diff.v1 cases PLUS `manifest.json` (`schema: 1, bug: 832`) and
`mock-cert.Login.json` (`schema: 1, spec: 1001`) in the exact shapes
`FixtureRegistry.writeManifest` / `MockCertReceipt.toJson` emit:

```
$ zfa tdd realize-mock Login --against=firestore --feature 1391-demo-login
   tier-1 contract test green (exit 0)
   method getAllLogins   tier1={"items":[...]} tier2={"items":[...]} diff=none
   method getById        tier1={"id":"u1",...} tier2={"id":"u1",...}      diff=none
   skipped manifest.json (schema 1)
   skipped mock-cert.Login.json (schema 1)
   method saveLogin      tier1={"id":"u2"} tier2={"id":"u2"}              diff=none
   receipt: .zfa/receipts/realize.Login.firestore.receipt.json (3 method record(s), verdict certified)
realize-mock: entity=Login against=firestore feature=1391-demo-login methods=3 mismatch=0 result=certified
EXIT CODE: 0
```

The registry files stay in place; no hand removal; the gate certifies.

## Success criteria

- **SC-1 PROVED** — A1: exit 0, `result=certified`, `methods=3
  mismatch=0`, both `skipped ... (schema 1)` lines, receipt carries
  exactly getById/saveLogin/getAllLogins, no `runner-error`.
- **SC-2 PROVED** — A2a: `skipped foreign.json (schema world-v2)`; the
  remaining case certifies.
- **SC-3 PROVED** — A3: foreign-only dir → exit 1, `result=blocked`
  (never `runner-error`, never a 0-method certification), message names
  the 2 skipped documents, no receipt written.
- **SC-4 PROVED** — A4: pure realize-diff.v1 dir → zero `skipped` lines,
  same certified outcome and receipt shape (backward compatibility).
- **SC-5 PROVED** — A5: realize-diff.v1-stamped case missing `input.op`
  → `carries no input.op`, `result=runner-error` (fail-closed intact).

## Constraint audit (hard constraints from the issue)

- Only realize-mock's fixture scan changed (`realize_mock_command.dart`:
  scan loop classification + post-scan guard + `_schemaLabel` renderer +
  comments). The core engine cycle, the `mock certify` command, the #832
  registry format, the `realize-diff.v1` schema, the receipt document,
  and the era-tagged log format are untouched (verified by the 16
  pre-existing realize-mock tests passing unchanged).
- One PR per issue; conventional-commit subject `fix(1391):`.

## Review fix round (PR #1477 review findings)

Verdict for this round: **PASSED**. The reviewer's major finding was that
an unparseable document was skipped as `schema unknown` even when it was a
corrupt case of the gate's OWN schema — so a truncated `realize-diff.v1`
case silently shrank the certified surface while the gate still printed
`result=certified`. Reproduced as A5c (see `tdd/cycle-log.md`, red cycle
`… (red — review fix round)`): `skipped truncated.json (schema unknown)` /
`methods=1 mismatch=0 result=certified` / `Expected: <1> Actual: <0>`.

| Item | Thread | Verdict |
| --- | --- | --- |
| Corrupt-but-stamped case fails closed | `realize_mock_command.dart:361-367` (major) | applied — the scan keeps the raw text and fails `runnerError` when the document does not decode AND the bytes carry the `realize-diff.v1` stamp |
| False fail-closed message reworded | `realize_mock_command.dart:375-377` (minor) | applied — "is stamped realize-diff.v1 but carries no input map" |
| AC-5 fail-closed coverage | `bug_1391_…_test.dart:310-321` (minor) | applied — A5a (no `input` key), A5b (`input` not an object), A5c (truncated stamped case) |
| `_schemaLabel` length cap | `plan.md:89-90` (nitpick) | applied — capped at 60 characters like `_preview`; the plan note now names the cap |
| Unreachable blanket `catch` | `realize_mock_command.dart:870-878` (nitpick) | applied — narrowed to `on JsonUnsupportedObjectError` |

Evidence: 10/10 in the #1391 suite, **26/26** across the three
realize-mock suites, `dart analyze` clean on both changed `.dart` files,
`dart format --set-exit-if-changed` 0 changed. A2c (unparseable JSON
WITHOUT the stamp → `skipped broken.json (schema unknown)`, certified)
stays green, so the foreign-file path is unchanged. `spec.md` (AC-2,
AC-5, FR-002, FR-004, SC-6) and `tasks.md` (T010) were updated to match
the shipped behavior.
