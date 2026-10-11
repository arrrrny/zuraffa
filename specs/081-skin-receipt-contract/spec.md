# Feature Specification: skin receipt proves contract enforcement (stage 4/4 of #1111)

**Feature Branch**: `081-skin-receipt-contract` | **Created**: 2026-09-05 | **Status**: Draft

**Input**: GitHub issue #1167 — `04-skin-receipt.json` gains `contract_schema_version` and `contract_rows_audited` derived from the live kit; parity test; sandbox proof.

## Requirements

- **FR-001**: The skin receipt MUST record the declared contract's schema version when the feature's spec declares `## Skin Contract:`; features without a contract omit the field additively (skin.v1-compatible).
- **FR-002**: The receipt MUST record `contract_rows_audited` — the declared contract rows enforced by the cycle: declared rows whose view is covered by a conformed behavior's artifacts. Zero when nothing conformed.
- **FR-003**: An unparseable contract MUST record no contract fields rather than inventing enforcement.
- **FR-004**: A parity test MUST assert every runtime row field has a schema row (078's generated schema), and the audited count MUST cross-check against the declared rows (SC-4).

## Success Criteria

- **SC-001**: A conformed cycle on a contract-bearing feature writes `contract_schema_version: "1"` and the audited count; a contract-less feature's receipt is byte-compatible with skin.v1.
- **SC-002**: `dart test test/plugins/tdd/` receipt suites green.

## Assumptions

- The sandbox end-to-end proof (`~/zik_zak_test`, `flutter test test/tdd/006-login-skin/`) requires the sandbox project, which is not present on this machine; the substance (receipt fields + parity) is delivered in core, and the sandbox run remains the operator's proof step.
