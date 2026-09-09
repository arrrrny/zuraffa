# Test List: 004-login-ui

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the verdict is invalid with a reason naming the email field first. | AC-1 | PENDING |
| A2 | the verdict is invalid with a reason naming the email field. | AC-2 | PENDING |
| A3 | the verdict is invalid with a reason naming the password field. | AC-3 | PENDING |
| A4 | the verdict is valid and the submit action is enabled. | AC-4 | PENDING |
| A5 | the result is a success carrying the authenticated user's email. | AC-5 | PENDING |
| A6 | the result is a failure carrying a non-empty error reason. | AC-6 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`. | FR-001, LoginValidation.validate | PENDING |
| U2 | The system MUST require the password to be at least 8 characters long. | FR-002, LoginValidation.validate | PENDING |
| U3 | The system MUST keep the submit action disabled until the credential verdict is valid. | FR-003, LoginValidation.validate | PENDING |
| U4 | The system MUST map a successful auth attempt to a result carrying the user's email and a null error. | FR-004, AuthGateway.signIn | PENDING |
| U5 | The system MUST map a rejected auth attempt to a result carrying a non-empty error reason and a null user email. | FR-005, AuthGateway.signIn | PENDING |
| U6 | Validation MUST be deterministic: the same input always yields the same verdict. | FR-006, LoginValidation.validate | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in `spec.md` Layer Contracts (issue #1007). A contract test proves the implementation satisfies the DECLARED contract — a failing contract test is BLOCKED (never RED) and blocks the cycle from proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | LoginValidation.validate(email, password) -> LoginVerdict (usecase contract) | LoginValidation.validate | PENDING |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| AuthGateway | service | `signIn(email, password) -> LoginResult` | P1 |

## Layer contracts

### Domain

- `LoginValidation`: `validate(email, password) -> LoginVerdict`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 26]
route: A2 -> acceptance lane [declared: type marker, spec line 28]
route: A3 -> acceptance lane [declared: type marker, spec line 30]
route: A4 -> acceptance lane [declared: type marker, spec line 32]
route: A5 -> acceptance lane [declared: type marker, spec line 47]
route: A6 -> acceptance lane [declared: type marker, spec line 49]
route: U1 -> unit lane [declared: contract row: LoginValidation, spec line 74]
route: U2 -> unit lane [declared: contract row: LoginValidation, spec line 74]
route: U3 -> unit lane [declared: contract row: LoginValidation, spec line 74]
route: U4 -> unit lane [declared: dependency row: AuthGateway, spec line 87]
route: U5 -> unit lane [declared: dependency row: AuthGateway, spec line 87]
route: U6 -> unit lane [declared: contract row: LoginValidation, spec line 74]
route: contract:A1 -> contract lane [declared: LoginValidation]

