# Test List: 1129-test-explain-flag

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa test create <Entity> --explain` emits the explain block: separator `--- explain: test create ---` plus the sections `generated files:`, `test kinds:`, `self-certification:`, `trust tier:`, `summary:`. | AC-US1-1 / FR-001, FR-002 | DONE |
| A2 | The explain block is additive: the machine verdict line and the created/overwritten file list still appear alongside it. | AC-US1-2 / FR-001 | DONE |
| A3 | Without `--explain`, stdout contains no `--- explain:` separator. | AC-US1-3 / FR-004 | DONE |
| A4 | `--explain --json` prints the parseable certification envelope `{entity, tests, compile, errors[], schema:1}` FIRST, then the prose block. | AC-US2-1 / FR-003 | DONE |
| A5 | `--json` alone stays envelope-only: existing keys unchanged, no explain prose (pre-1129 stdout). | AC-US2-2 / FR-004 | DONE |
| A6 | Passing analyzer ⇒ every written file `tier=certified`, block tier `certified`. | AC-US3-1 / FR-006 | DONE |
| A7 | Failing analyzer ⇒ offending file `tier=failed` with the first error quoted; block tier `failed`. | AC-US3-2 / FR-006 | DONE |
| A8 | Skipped pre-existing file ⇒ `tier=pre-existing`; it does not lower the block tier of the written files. | AC-US3-3 / FR-006 | DONE |
| A9 | Manifest treaty: `zfa manifest --verify test` certifies the schema-advertised `--explain` flag with zero drift findings. | FR-008 / SC-5 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `buildTestExplain` starts the block with the `--- explain: test create ---` separator and ends with the `summary:` section. | FR-001, FR-002 | DONE |
| U2 | `generated files:` lists one line per produced file with path, action, `kind=` and `tier=`. | FR-002 | DONE |
| U3 | `test kinds:` reports honest lanes: `unit=N` for produced unit tests, `integration=0, widget=0` when not produced. | FR-007 | DONE |
| U4 | `self-certification:` carries one per-file line plus the machine verdict line `test: entity=<X> tests=<N> compile=pass\|fail`. | FR-002 | DONE |
| U5 | Trust tier derivation: no attributed error ⇒ `certified`; attributed error ⇒ `failed`; no certification evidence ⇒ `unverified`; skipped ⇒ `pre-existing`. | FR-006 | DONE |
| U6 | Block-level tier is the floor over the files this run wrote (`failed` > `unverified` > `certified`); `pre-existing` never lowers it. | FR-006 | DONE |
| U7 | `TestCreateCommand` parses the positional entity + `--name/--methods/--domain/--dry-run/--force/--verbose/--revert/--json/--explain` and maps them onto capability args. | FR-001, FR-008 | DONE |
| U8 | `TestCreateCommand` delegates to `CreateTestCapability.execute` through `CapabilityInvocationWrapper` (receipt persistence preserved). | FR-005 | DONE |
| U9 | `CreateTestCapability.execute` with `explain: true` attaches `data['explain']` containing the sections; `data['certification']` shape unchanged (`{entity, tests, compile, errors[], schema:1}`). | FR-003, FR-004 | DONE |
| U10 | Non-compiling generation: capability returns success=false; the bespoke command still prints the explain block (honesty on every exit path) and exits 1 — the gate is unchanged. | FR-005 | DONE |
| U11 | #769 zero-files guard: all-skipped generation keeps the warning + exit 1, and `--explain` still prints the block naming the pre-existing files. | FR-001 | DONE |
| U12 | Schema↔grammar parity: every capability inputSchema property (name, methods, domain, dry-run, force, verbose, explain) resolves to a registered, help-advertised flag on the serving command. | FR-008 | DONE |
