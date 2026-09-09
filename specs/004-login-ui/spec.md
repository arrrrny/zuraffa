# Feature Specification: Login UI — `004-login-ui`

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `spec/004-login-ui`

**Created**: 2026-09-09

**Status**: Draft

**Input**: User description: "EPIC 5 (#1136) verify exit criterion: a login feature named 004-login-ui that the spec-mutation arena can fuzz (`zfa spec fuzz 004-login-ui`), with testable login-form intent"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Credential validation gates the form (Priority: P1)

A user typing into the login form receives immediate, deterministic validation feedback: the email must be a well-formed address and the password must satisfy the declared policy. The submit action stays disabled until both fields are valid, so an invalid submission can never reach the auth layer.

**Why this priority**: validation is the form's behavioral core; every later story (submission, error surfacing) depends on a gated submit.

**Independent Test**: call the form's validation function with sample inputs and assert the verdict; assert the submit gate flips only when both fields validate.

**Acceptance Scenarios**:

1. **Given** an empty email and an empty password, **When** the form is validated, **Then** the verdict is invalid with a reason naming the email field first.
   **Type**: acceptance
2. **Given** an email missing the `@` separator, **When** the form is validated, **Then** the verdict is invalid with a reason naming the email field.
   **Type**: acceptance
3. **Given** a password shorter than 8 characters, **When** the form is validated, **Then** the verdict is invalid with a reason naming the password field.
   **Type**: acceptance
4. **Given** a well-formed email and a password of at least 8 characters, **When** the form is validated, **Then** the verdict is valid and the submit action is enabled.
   **Type**: acceptance

---

### User Story 2 - Submit produces an auth attempt outcome (Priority: P2)

When the user submits valid credentials, the form invokes the declared auth touchpoint and maps the outcome to a login result the UI can render: success carries the signed-in user's email; failure carries a single non-null error reason. Exactly one of the two is ever non-null.

**Why this priority**: the form exists to sign the user in; without a mapped outcome the UI has nothing to render.

**Independent Test**: drive the submit path with a scripted auth touchpoint (success and failure) and assert the mapped result.

**Acceptance Scenarios**:

1. **Given** valid credentials and an auth touchpoint that accepts them, **When** the form is submitted, **Then** the result is a success carrying the authenticated user's email.
   **Type**: acceptance
2. **Given** valid-shaped credentials and an auth touchpoint that rejects them, **When** the form is submitted, **Then** the result is a failure carrying a non-empty error reason.
   **Type**: acceptance

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`.
  traces: LoginValidation.validate
- **FR-002**: The system MUST require the password to be at least 8 characters long.
  traces: LoginValidation.validate
- **FR-003**: The system MUST keep the submit action disabled until the credential verdict is valid.
  traces: LoginValidation.validate
- **FR-004**: The system MUST map a successful auth attempt to a result carrying the user's email and a null error.
  traces: AuthGateway.signIn
- **FR-005**: The system MUST map a rejected auth attempt to a result carrying a non-empty error reason and a null user email.
  traces: AuthGateway.signIn
- **FR-006**: Validation MUST be deterministic: the same input always yields the same verdict.
  traces: LoginValidation.validate

## Layer Contracts

**Domain**:

- `LoginValidation`: `validate(email, password) -> LoginVerdict`

### Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| `LoginCredentials` | `email: String`, `password: String` | The credential pair the user submits |
| `LoginResult` | `email: String?`, `error: String?` | The mapped outcome of an auth attempt (exactly one field non-null) |

### External Dependencies & Contracts

| Dependency | Kind | Contract | Priority |
|--------|--------|--------|--------|
| AuthGateway | service | `signIn(email, password) -> LoginResult` | P1 |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every declared acceptance scenario runs green through the TDD loop (`zfa tdd run 004-login-ui`).
- **SC-002**: The spec survives a spec-fuzz round with every survived mutant reported to the gap ledger (`zfa spec fuzz 004-login-ui`).
