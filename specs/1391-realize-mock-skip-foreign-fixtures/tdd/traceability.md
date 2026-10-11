# Traceability: 1391-realize-mock-skip-foreign-fixtures

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:a8246182df4da32027e6b98ca48a2f5e928b0db73b388a8ce8ee665697ef0e89
statements: 12
automated: 12
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 31 | 1. **Given** a feature whose `specs/<f>/tdd/fixtures/` holds the three committed `realize-diff.v1` contract cases AND the #832 registry artifacts (`manifest.json` with `schema: 1` and `mock-cert.Login.json` with `schema: 1`) written by `zfa mock certify Login --feature <f>`, **When** the user runs `zfa tdd realize-mock Login --against=firestore`, **Then** the gate exits 0 with verdict `certified`, runs all three real cases, prints `skipped manifest.json (schema 1)` and `skipped mock-cert.Login.json (schema 1)`, and the receipt carries the 3 method records — no runner-error, no hand removal of registry files. | A1 | automated |
| AC-2 | 33 | 2. **Given** a fixtures directory holding a foreign JSON document whose `schema` is any non-`realize-diff.v1` value (a string such as `world-v2`, a number such as `1`, or absent/unparseable JSON), **When** realize-mock's fixture scan reads the document, **Then** the scan skips it and logs `skipped <name> (schema <x>)` where `<name>` is the file basename and `<x>` is the document's schema value rendered verbatim (or `unknown` when absent or the file is not parseable JSON) — the scan never fails on a foreign document. | A2 | automated |
| AC-3 | 35 | 3. **Given** a fixtures directory whose every `.json` document is foreign (no `realize-diff.v1` case remains after skipping), **When** realize-mock runs, **Then** it fails with `result=blocked` (exit 1) naming that no `realize-diff.v1` contract cases remain after the foreign documents were skipped — an empty surface is never certified. | A3 | automated |
| AC-4 | 37 | 4. **Given** a feature with only `realize-diff.v1` fixtures (no #832 artifacts anywhere in the directory), **When** realize-mock runs, **Then** the behavior is unchanged: no `skipped` lines, the same per-method differential, the same receipt and verdict as before this change (backward compatibility). | A4 | automated |
| AC-5 | 39 | 5. **Given** a document that IS stamped `schema: "realize-diff.v1"` but is malformed (missing `input` or `input.op`), **When** the scan classifies it, **Then** the scan still fails closed with the existing "fix the fixture before certifying" validation — the skip path is reserved for foreign documents, and a broken contract case of the gate's own schema remains a hard error. | A5 | automated |
| FR-001 | 44 | - **FR-001**: realize-mock's fixture scan MUST classify each `.json` | U1 | automated |
| FR-002 | 48 | - **FR-002**: For every scanned document whose schema is not the exact | U2 | automated |
| FR-003 | 56 | - **FR-003**: `manifest.json` and `mock-cert.*.json` (the #832 registry | U3 | automated |
| FR-004 | 61 | - **FR-004**: A document stamped `realize-diff.v1` that is malformed | U4 | automated |
| FR-005 | 66 | - **FR-005**: When every scanned document was skipped (zero contract | U5 | automated |
| FR-006 | 70 | - **FR-006**: Backward compatibility: a feature whose fixtures directory | U6 | automated |
| FR-007 | 74 | - **FR-007**: Scope guard: ONLY realize-mock's fixture scan changes. The | U7 | automated |

