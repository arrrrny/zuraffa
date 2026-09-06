# Test List: 1141-i18n-keyed-widget-contracts (issue #1141)

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the keyed 004-login-ui view regenerates with zero hardcoded user-facing strings | FR-004 | PENDING |
| A2 | the EN copy edit 'Sign in' to 'Log In' leaves the generated test's keyed assertions byte-identical | FR-004 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | zfa tdd plan writes specs/<f>/tdd/ui-ledger.md with t.<key> rows (keyed anchors feed key rows, never text rows) | FR-001 | PENDING |
| U2 | zfa tdd plan writes the empty ledger for a zero-surface spec (visible fact, never an omission) | FR-001 | PENDING |
| U3 | zfa tdd view audits the rendered view before any write and refuses untraced-surface violations with a fix line | FR-002 | PENDING |
| U4 | zfa tdd view refuses a hardcoded declared anchor as a hardcoded-key violation naming the required accessor | FR-002 | PENDING |
| U5 | zfa tdd view keeps non-i18n hosts byte-identical (traced literals, exit 0 — zero drift) | FR-002 | PENDING |
| U6 | zfa build runs the slang codegen stage before build_runner when lib/i18n sources exist | FR-003 | PENDING |
| U7 | zfa build skips the stage without i18n sources and defers when build.yaml wires slang_build_runner | FR-003 | PENDING |
| U8 | zfa build fails with an actionable fix line when sources exist but slang is unresolvable | FR-003 | PENDING |
| U9 | the 004-login-ui regeneration composes: keyed view + slang-shell test + merged scaffold + ledger rows | FR-004 | PENDING |

## Layer contracts

### Presentation

- `ViewAuditContract`: `key: auth.signIn -> 'Sign in'`, `key: auth.email -> 'Email'`, `key: auth.password -> 'Password'`, `key: auth.sessionStarted -> 'Session started'`
