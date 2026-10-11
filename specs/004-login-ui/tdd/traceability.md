# Traceability: 004-login-ui

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:9205eb7c52f7bb34359c1e20760da0ce38ce59fb710318c8f213b3d042b8be4c
statements: 12
automated: 12
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 25 | 1. **Given** an empty email and an empty password, **When** the form is validated, **Then** the verdict is invalid with a reason naming the email field first. | A1 | automated |
| AC-2 | 27 | 2. **Given** an email missing the `@` separator, **When** the form is validated, **Then** the verdict is invalid with a reason naming the email field. | A2 | automated |
| AC-3 | 29 | 3. **Given** a password shorter than 8 characters, **When** the form is validated, **Then** the verdict is invalid with a reason naming the password field. | A3 | automated |
| AC-4 | 31 | 4. **Given** a well-formed email and a password of at least 8 characters, **When** the form is validated, **Then** the verdict is valid and the submit action is enabled. | A4 | automated |
| AC-5 | 46 | 1. **Given** valid credentials and an auth touchpoint that accepts them, **When** the form is submitted, **Then** the result is a success carrying the authenticated user's email. | A5 | automated |
| AC-6 | 48 | 2. **Given** valid-shaped credentials and an auth touchpoint that rejects them, **When** the form is submitted, **Then** the result is a failure carrying a non-empty error reason. | A6 | automated |
| FR-001 | 57 | - **FR-001**: The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`. | U1 | automated |
| FR-002 | 59 | - **FR-002**: The system MUST require the password to be at least 8 characters long. | U2 | automated |
| FR-003 | 61 | - **FR-003**: The system MUST keep the submit action disabled until the credential verdict is valid. | U3 | automated |
| FR-004 | 63 | - **FR-004**: The system MUST map a successful auth attempt to a result carrying the user's email and a null error. | U4 | automated |
| FR-005 | 65 | - **FR-005**: The system MUST map a rejected auth attempt to a result carrying a non-empty error reason and a null user email. | U5 | automated |
| FR-006 | 67 | - **FR-006**: Validation MUST be deterministic: the same input always yields the same verdict. | U6 | automated |

