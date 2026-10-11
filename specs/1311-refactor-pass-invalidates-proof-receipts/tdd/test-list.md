# TDD Test List — Spec 1311 refactor pass invalidates proof receipts

One behavior per line, traced to the acceptance scenarios / FRs in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to pass
(GREEN). Red for this feature is an assertion red: pre-fix, the sanctioned
refactor leaves digest drift, so the AC2/AC3 assertions fail on the
`modified` findings (recorded below).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | A sanctioned refactor that formats a receipted lib artifact appends one proof.v1 event (command `tdd refactor`, `input.feature`, sanctioned/refactor provenance, pass names) covering the mutated path with action `update` and the digest of the FORMATTED bytes | FR-1, FR-5 / AS-1 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B2 | After the sanctioned refactor, `ProofChecker.check()` reports zero `modified` findings for the receipted paths (the refresh re-hashed them; latest-wins holds) | FR-1 / AS-1 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B3 | End-to-end: `zfa proof check --format json` exits 0 with `ok: true` and zero findings after the sanctioned refactor | FR-2 / AS-2 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B4 | After the sanctioned refactor, `zfa tdd verify --feature <f>` does NOT refuse with the proof-preflight drift NOT_ASSESSED; the receipt preflight reports ok and the audit phase is reached (audit verdict semantics unchanged) | FR-3 / AS-3 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B5 | A refactor that mutates nothing (already-clean lib) appends NO refactor receipt; the receipts tree is unchanged | FR-4 / AS-4 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B6 | A refactor that mutates only unreceipted files appends NO refactor receipt | FR-4 / AS-4 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B7 | Service unit: `refresh` with changed∩receipted = ∅ returns fired=false and writes nothing | FR-4 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B8 | Service unit: `refresh` with overlap writes the event with honest re-derived digests/bytes from disk; a second event after another mutation appends (append-only) and latest-wins resolves to the newest digest | FR-1, FR-5 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |
| B9 | A red preflight refusal (or misfire/regression) appends NO refactor receipt — only a completed sanctioned pass refreshes | FR-4 / AS-5 | test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart --tag-filter 'slow' # B1-B6 (CLI, slow tier)
dart test test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart # all groups
```

Expected RED evidence (pre-fix): B1 (no refactor receipt), B2/B3
(`modified` digest-drift findings, proof check exit 1), B4 (NOT_ASSESSED
proof-preflight refusal), B7/B8 (service does not exist — compile error
counts as red-protocol TODO, re-run after skeleton), B5/B6 expected GREEN
pre-fix (the no-op behavior already holds) — they pin the backward-compat
line against regressions.
