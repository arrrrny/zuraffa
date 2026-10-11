**Template Version**: `zuraffa-1.0`

# Bug Spec: 1603 — a MISSING subject file is not "outside the project root" on symlinked roots

**Input**: GitHub issue #1603 — `zfa tdd view` reports a missing subject file as
"points outside the project root" whenever the project root reaches the filesystem
through a symlink that `Directory.resolveSymbolicLinks()` expands (`/var/folders` →
`/private/var/folders` on macOS). Found while verifying PR #1581.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd view` MUST report the missing-subject refusal ("points to a
  missing subject file") for a recorded subject that does not exist, even when the
  project root resolves through a symlink: before the outside-root comparison the
  missing subject MUST be canonicalized through its nearest EXISTING ancestor
  (resolve that ancestor, re-append the remaining missing segments).
            traces: ViewCommand
- **FR-002**: `zfa tdd view` MUST keep refusing a recorded subject that genuinely
  resolves outside the project root ("points outside the project root") — the
  FR-001 canonicalization never widens the accepted root.
            traces: ViewCommand

## Layer Contracts

**Function**:
- `ViewCommand`: `run() -> Future<void>`

## Acceptance Scenarios

1. **Given** a fixture project whose root path resolves through a symlink **When**
   `zfa tdd view` runs for a registered behavior whose recorded subject file is
   missing **Then** the refusal names the missing subject file (never "outside the
   project root") and exits non-zero.
   **Type**: acceptance
2. **Given** a recorded subject that genuinely resolves outside the project root
   **When** `zfa tdd view` runs **Then** the refusal still names "points outside
   the project root".
   **Type**: acceptance
