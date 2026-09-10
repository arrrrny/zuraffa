**Template Version**: `zuraffa-1.0`

# Spec: 1391-realize-mock-skip-foreign-fixtures

## Overview

`zfa mock certify <Entity> --feature <f>` (issue #1001, the #832 registry)
writes `manifest.json` (`schema: 1`, `bug: 832`) and
`mock-cert.<Entity>.json` (`schema: 1`, `spec: 1001`) into the feature's
`specs/<f>/tdd/fixtures/` directory by design. `zfa tdd realize-mock
<Entity> --against=firestore` (issue #1009, the differential gate) consumes
the same directory and is intolerant of foreign JSON: its fixture scan
treats every `.json` file as a `realize-diff.v1` contract case, so the two
registry files crash the gate with
`fixture manifest is not a realize-diff.v1 document (schema, input.op missing)`
— exit 1, `result=runner-error` — after the real cases have already passed.
Any feature that registers its fixtures per #1001 then cannot run the
differential gate per #1009 until the registry files are hand-removed.

This spec makes realize-mock's fixture scan schema-aware: a document is a
contract case if and only if it carries `schema: "realize-diff.v1"`;
every other document is SKIPPED with a `skipped <name> (schema <x>)` log
line so foreign files stay visible without breaking the gate. Certify and
realize-mock coexist in the same fixtures directory.

GitHub issue #1391 (severity medium — VERIFY misfire from EPIC #1014;
missing integration: each sub-issue works alone, the combined flow breaks).

## Acceptance Scenarios

1. **Given** a feature whose `specs/<f>/tdd/fixtures/` holds the three committed `realize-diff.v1` contract cases AND the #832 registry artifacts (`manifest.json` with `schema: 1` and `mock-cert.Login.json` with `schema: 1`) written by `zfa mock certify Login --feature <f>`, **When** the user runs `zfa tdd realize-mock Login --against=firestore`, **Then** the gate exits 0 with verdict `certified`, runs all three real cases, prints `skipped manifest.json (schema 1)` and `skipped mock-cert.Login.json (schema 1)`, and the receipt carries the 3 method records — no runner-error, no hand removal of registry files.
   **Type**: acceptance
2. **Given** a fixtures directory holding a foreign JSON document whose `schema` is any non-`realize-diff.v1` value (a string such as `world-v2`, a number such as `1`, an absent schema, or unparseable JSON whose bytes do not carry the `realize-diff.v1` stamp), **When** realize-mock's fixture scan reads the document, **Then** the scan skips it and logs `skipped <name> (schema <x>)` where `<name>` is the file basename and `<x>` is the document's schema value rendered verbatim, capped at 60 characters (or `unknown` when absent or the file is not parseable JSON) — the scan never fails on a foreign document.
   **Type**: acceptance
3. **Given** a fixtures directory whose every `.json` document is foreign (no `realize-diff.v1` case remains after skipping), **When** realize-mock runs, **Then** it fails with `result=blocked` (exit 1) naming that no `realize-diff.v1` contract cases remain after the foreign documents were skipped — an empty surface is never certified.
   **Type**: acceptance
4. **Given** a feature with only `realize-diff.v1` fixtures (no #832 artifacts anywhere in the directory), **When** realize-mock runs, **Then** the behavior is unchanged: no `skipped` lines, the same per-method differential, the same receipt and verdict as before this change (backward compatibility).
   **Type**: acceptance
5. **Given** a document that IS stamped `schema: "realize-diff.v1"` but is malformed — missing `input`, an `input` that is not an object, missing `input.op`, or raw bytes that carry the stamp yet do not decode to a JSON object (a truncated or corrupted case) — **When** the scan classifies it, **Then** the scan still fails closed with `result=runner-error` and a "fix the fixture before certifying" validation, writing no receipt: the skip path is reserved for foreign documents, and a broken contract case of the gate's own schema remains a hard error that can never silently shrink the certified surface.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: realize-mock's fixture scan MUST classify each `.json`
  document by its `schema` field: a document is a contract case if and
  only if the decoded document is a JSON object whose `schema` equals the
  exact string `realize-diff.v1`.
- **FR-002**: For every scanned document whose schema is not the exact
  string `realize-diff.v1` (different value, absent, non-object JSON, or
  unparseable JSON) and whose raw bytes do not carry the `realize-diff.v1`
  stamp, the scan MUST skip the document and log
  `skipped <name> (schema <x>)` where `<name>` is the file basename (with
  extension) and `<x>` is the schema value rendered (`1` for the #832
  artifacts, the string verbatim for string schemas, `unknown` when
  absent or unparseable). The rendered value is capped at 60 characters.
  A skipped document MUST produce no method record, no receipt row, and
  no failure.
- **FR-003**: `manifest.json` and `mock-cert.*.json` (the #832 registry
  artifacts, both `schema: 1`) MUST be skipped without error — the
  combined `mock certify --feature` + `tdd realize-mock` flow (issues
  #1001 x #1009) completes end-to-end without hand-removing registry
  files.
- **FR-004**: A document that carries the `realize-diff.v1` stamp but is
  malformed MUST fail closed with `result=runner-error` (exit 1), no
  receipt written, and a validation message ending "fix the fixture
  before certifying" — malformed means missing `input`, an `input` that
  is not an object, missing `input.op`, or raw bytes that carry the stamp
  yet do not decode to a JSON object (a truncated case). Skip applies to
  foreign documents only, never to a broken case of the gate's own
  schema, so a corrupted case can never silently shrink the certified
  surface.
- **FR-005**: When every scanned document was skipped (zero contract
  cases remain), realize-mock MUST fail with `result=blocked` (exit 1)
  and a message naming the skip — it MUST NOT certify zero methods and
  MUST NOT report runner-error (the crash outcome this fix removes).
- **FR-006**: Backward compatibility: a feature whose fixtures directory
  holds only `realize-diff.v1` cases MUST behave exactly as before —
  same exit code, same verdict, same receipt content, and zero `skipped`
  log lines.
- **FR-007**: Scope guard: ONLY realize-mock's fixture scan changes. The
  core engine cycle, the `mock certify` command, the #832 registry
  format, the `realize-diff.v1` schema, and the differential/receipt
  semantics are unchanged.

## Success Criteria

- SC-1: The issue #1391 repro (fixtures dir = 3 realize-diff.v1 cases +
  `manifest.json` + `mock-cert.Login.json`) runs realize-mock to exit 0,
  verdict `certified`, exactly 3 method records, and the two `skipped
  ... (schema 1)` lines printed (AC-1, AC-2).
- SC-2: A foreign document with a string schema (e.g. `world-v2`) is
  skipped with `skipped <name> (schema world-v2)` and the remaining
  contract cases still certify (AC-2).
- SC-3: A foreign-only fixtures directory yields `result=blocked`
  (exit 1), never `result=runner-error` and never verdict `certified`
  with 0 methods (AC-3).
- SC-4: A pure realize-diff.v1 fixtures directory produces zero `skipped`
  lines and the unchanged certified outcome (AC-4).
- SC-5: A `realize-diff.v1`-stamped document missing `input.op` still
  fails with the existing validation message (AC-5) — the fail-closed
  contract survives.
- SC-6: A `realize-diff.v1`-stamped document whose `input` key is absent
  or is not an object fails closed with `result=runner-error` and the
  "carries no input map" message, and a truncated document whose bytes
  still carry the stamp fails closed as corrupt (never `skipped …
  (schema unknown)`, never `certified`); neither writes a receipt for the
  reduced surface (AC-5).

## Out of Scope

- The core engine cycle, the `mock certify` command, the #832 registry
  format, and the `realize-diff.v1` schema are unchanged (hard
  constraint, issue #1391).
- No change to the differential harness used by other commands
  (`realize --diff`, `diff-check`): only realize-mock's fixture scan.
- No receipt-format change: the realize-mock receipt document and the
  era-tagged cycle-log entry format stay as-is (skipped files are
  surfaced through the log line, not new fields).
- No migration or rewriting of foreign documents; the gate leaves them
  in place.

## Assumptions

- The `schema` field of a `realize-diff.v1` document is the exact string
  `realize-diff.v1`; every in-repo writer (the #1367 mock-cert fallback
  synthesis, the differential harness documentation, and the committed
  test helpers) stamps it that way.
- The #832 artifacts are identified behaviorally (their `schema` is the
  integer `1`), not by filename pattern; the filename-based shortcut
  (`manifest.json`, `mock-cert.*.json`) is covered by the same rule
  because both carry `schema: 1`.
- Feature home resolution, tier-1 contract-test execution, tier-2
  provider seeding, and the receipt writer are untouched.
