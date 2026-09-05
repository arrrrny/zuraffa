# Traceability: 990-tdd-plan-migrate-spec-marker

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:577432710aa2b58f620da10599bfd3284e795e5c6abb93b7958c4408e539f3eb
statements: 6
automated: 6
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 7 | 1. **Given** a spec whose frontmatter carries no `**Template Version**` marker **When** the user runs `zfa tdd plan <feature> --migrate-spec` **Then** the latest known template version is inserted at the top of `spec.md`, the migration is reported on stdout, and the test list is generated in the same run. | A1 | automated |
| FR-001 | 11 | - **FR-001**: The plan command accepts a `--migrate-spec` flag that migrates a non-conformant spec to the latest known template version and then proceeds with the normal plan flow. | U1 | automated |
| FR-002 | 12 | - **FR-002**: A missing (non-fenced) `**Template Version**` marker is injected at the top of the spec frontmatter, followed by a blank line, with every other byte of the spec preserved verbatim. | U2 | automated |
| FR-003 | 13 | - **FR-003**: A stale or unknown `**Template Version**` marker is refreshed in place to the latest known template version, and a marker mentioned only inside a fenced code block is never treated as the pin nor rewritten. | U3 | automated |
| FR-004 | 14 | - **FR-004**: Migration is idempotent — a spec already pinning a known template version is left byte-identical and no migration notice is printed. | U4 | automated |
| FR-005 | 15 | - **FR-005**: The contract drift gate itself is unchanged — without `--migrate-spec`, a missing or unknown marker still exits 3 with the fix line, no artifacts, and the spec file is never mutated. | U5 | automated |

