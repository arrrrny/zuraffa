# Research: skin-contract.v1 (issue #1164)

## R1: Reuse vs. duplicate the runtime skin types

**Decision**: the contract model references the existing runtime vocabulary — row shapes
align with `SkinContractRow` (`lib/src/skin/skin_contract_row.dart`) and platform slots
with `SkinTargetPlatform` (`tree_facts.dart`) — but the contract model is its own module
(`lib/src/skin/contract/`), not an extension of the runtime kit.

**Rationale**: #1111 draws a hard line: the contract is the declaration, the kit is the
enforcement. Stage 2 (#1165) will bind them. One vocabulary, two roles.

**Alternatives considered**: extend `SkinContractRow` with parse/validate — blurs the
declaration/enforcement boundary and drags runtime scheduler dependencies into the parser.

## R2: Emitter hook placement

**Decision**: emit in `plan_command.dart` after lane resolution: if the spec contains a
`## Skin Contract:` section, write `specs/<feature>/tdd/04-skin-contract.schema.json`;
otherwise write nothing.

**Rationale**: issue #1000's lane machinery is already the spec-reading, tdd/-writing
part of plan; the schema is another generated lane artifact. Regeneration is
deterministic overwrite (the receipts convention).

**Alternatives considered**: a separate `zfa skin contract` command — more surface to
keep in sync, and #1111 explicitly names `zfa tdd plan` as the emitter.

## R3: Contract JSON shape (v1)

**Decision**:

```json
{
  "schemaVersion": "1",
  "routes": [{ "path": "/login", "view": "LoginPage" }],
  "states": [{ "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }],
  "platformRows": [{ "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }],
  "stateRows": [{ "view": "LoginPage", "row": "error-toaster", "kind": "observer" }]
}
```

**Rationale**: section names mirror #1111's own words (`contract.routes`, `contract.states`,
`contract.platformRows`, `contract.stateRows`); rows are keyed by view so stage 4's
`contract_rows_audited` count maps 1:1 onto the live kit's rows.

**Alternatives considered**: maps keyed by view — JSON keys would carry dots/paths poorly
and lose ordering; arrays of keyed objects validate cleanly in JSON Schema.

## R4: Strict parsing

**Decision**: unknown top-level or per-row fields fail the parse naming the key; missing
required sections fail naming the section; `schemaVersion` must be `"1"`.

**Rationale**: the contract exists to be enforced; lenient parsing recreates the
"declaration that nothing consumes" problem #1111 was filed against.

## R5: Schema generation from the model

**Decision**: the schema is built by code that walks the model's field definitions (a
small declarative field table), so model and schema cannot drift; the emitter test pins
field parity in both directions.

**Rationale**: a hand-written schema would drift on the first model change; a generated
one makes drift a compile/test failure.
