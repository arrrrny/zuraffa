**Template Version**: `zuraffa-1.0`

# Spec: 990-tdd-plan-migrate-spec-marker

## Acceptance Scenarios

1. **Given** a spec whose frontmatter carries no `**Template Version**` marker **When** the user runs `zfa tdd plan <feature> --migrate-spec` **Then** the latest known template version is inserted at the top of `spec.md`, the migration is reported on stdout, and the test list is generated in the same run.

## Functional Requirements

- **FR-001**: The plan command accepts a `--migrate-spec` flag that migrates a non-conformant spec to the latest known template version and then proceeds with the normal plan flow.
- **FR-002**: A missing (non-fenced) `**Template Version**` marker is injected at the top of the spec frontmatter, followed by a blank line, with every other byte of the spec preserved verbatim.
- **FR-003**: A stale or unknown `**Template Version**` marker is refreshed in place to the latest known template version, and a marker mentioned only inside a fenced code block is never treated as the pin nor rewritten.
- **FR-004**: Migration is idempotent — a spec already pinning a known template version is left byte-identical and no migration notice is printed.
- **FR-005**: The contract drift gate itself is unchanged — without `--migrate-spec`, a missing or unknown marker still exits 3 with the fix line, no artifacts, and the spec file is never mutated.
