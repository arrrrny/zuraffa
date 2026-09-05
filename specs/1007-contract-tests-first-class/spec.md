# Feature Specification: Contract tests as a first-class `zfa tdd` test kind (issue #1007, VISION track)

**Feature Branch**: `spec/1007-contract-tests-first-class`

**Created**: 2026-09-05

**Status**: Draft

**Input**: Issue [#1007](https://github.com/arrrrny/zuraffa/issues/1007) — "[VISION] Contract tests as first-class zfa tdd test kind (substrate for dream)". A contract test is different from a unit test: it proves an implementation satisfies a **declared contract**, not that a piece of code does what its author said. This is the substrate for `zfa dream` — without contract tests, generated and hand-written code are graded by different rules. No contract test kind exists today.

**Template Version**: `zuraffa-1.0`

## Mission

`zfa tdd` grades behaviors today through two kinds: `unit` and `widget` (plus the hand-maintained `theme`/`platform`/`ffi` harness lanes). Every one of those pairs asserts a behavior's own prose — the author's claim about the code. None of them asserts a DECLARED contract: "the `Session` entity exposes `start(token)` and it satisfies the spec's declared cases". Generated code and hand-written code therefore play by different rules, which is exactly the ambiguity `zfa dream` (#1010) cannot afford: a dream loop that cannot grade an implementation against the declared contract will pass code that merely satisfies its own test's author.

This spec adds the `contract` behavior kind end to end: the plan derives `contract:<id>` rows from the spec's declared Layer Contracts (one row per entity method, controller method, and usecase), `zfa tdd gen` materializes a contract test scaffold that enumerates the contract's method cases, a failing contract test is a `BLOCKED` verdict (distinct from `RED`, with its own `contract-blocked.<id>.json` receipt) that blocks the cycle from proceeding to GREEN, and the corpus-economics gap ledger treats contract-test failures as the highest-severity gaps.

The contract kind is **additive**: existing unit/widget test semantics are untouched (hard constraint), a spec without Layer Contracts plans byte-identically to today, and the BLOCKED verdict exists only on the contract lane.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The plan derives contract rows from the declared contracts (Priority: P1)

An agent specs a login feature whose `## Layer Contracts` section declares the engine's interfaces and methods (a `Session` entity contract, a `LoginController` controller contract, a `LoginUseCase` usecase contract). `zfa tdd plan 004-login-ui` emits, alongside the acceptance and unit rows, one `contract:<id>` row per declared method — `contract:A1` for the first entity method — under a `## Contract loop:` section the shared `TestListReader` resolves as the new `contract` kind. In a lane-split spec the contract rows land in the engine plan.

**Why this priority**: without plan-level derivation there is nothing for gen to scaffold; this is the substrate every later step consumes.

**Independent Test**: seed a temp project with the 004-login-ui spec carrying Layer Contracts; run `zfa tdd plan 004-login-ui`; assert the engine plan contains `| contract:A1 |` rows and `TestListReader` resolves them with `BehaviorKind.contract`.

### User Story 2 - Gen scaffolds the contract test, not an implementation test (Priority: P1)

`zfa tdd gen contract:A1` writes the pair: a contract TEST that enumerates the declared method cases and asserts the implementation satisfies each one, plus a compilable contract SUBJECT harness carrying the case table (every case seam unsatisfied until the implementation lands). The artifacts are namespaced by feature (`test/tdd/<feature>/contract_a1_test.dart`, `lib/tdd/<feature>/contract_a1_subject.dart`), registered, and receipt-bound exactly like every other gen pair.

**Why this priority**: the exit criterion is literal — `zfa tdd gen contract:A1` must produce a contract test that enumerates method cases.

**Independent Test**: run the real gen in the fixture; assert the test file contains one `test('case ...')` per declared method and the subject carries the case table with unsatisfied seams.

### User Story 3 - A failing contract test is BLOCKED, not RED, and blocks GREEN (Priority: P1)

A deliberately unimplemented method makes the contract test fail through its case assertion. `zfa tdd verify-red contract:A1` does NOT certify a red: it reports `classification=blocked`, exits non-zero, writes NO red evidence into the cycle log, and persists the distinct receipt `.zfa/receipts/contract-blocked.<id>.json` carrying the blocked cases. In `zfa tdd run`, the `blocked` verify-red outcome stops the cycle at `stopped_at=<id>:verify-red` with `result=blocked` — the behavior never reaches make, so the cycle cannot proceed to GREEN while the contract is unsatisfied.

**Why this priority**: BLOCKED is the issue's core verdict distinction; without it a contract test would certify an ordinary red and the loop would "implement to green" past an unsatisfied contract.

**Independent Test**: fixture with a fake runner transcript carrying an assertion failure; run the real verify-red on a gen'd contract behavior; assert the blocked summary line, the receipt file, the absent cycle-log entry; drive `StepRunner` with an injected spawner returning the blocked summary and assert `outcome=blocked`.

### User Story 4 - The corpus-economics gate ranks contract failures highest (Priority: P2)

A corpus run that stops on a contract behavior appends its gap with `severity=contract`. `GapLedgerTotals` ranks contract-severity gaps above every other open gap (they head the blocking list) and counts them separately, and `zfa tdd corpus status` prints the severity so the highest-severity gaps are always the first thing an operator sees.

**Why this priority**: the gap ledger is the corpus economics' accounting surface; contract failures are the most expensive gaps because they block the dream substrate itself.

**Independent Test**: append contract and standard gaps through the real store; assert the totals rank contract first and the run/status surfaces label them.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The behavior kind enum MUST include `contract` alongside `acceptance`/`unit`/`widget`/`theme`/`ffi`/`platform`, and the shared `TestListReader` MUST resolve rows under a `## Contract loop:` section header (or a `contract` kind cell in the deprecated 6-column dialects) as `BehaviorKind.contract`. The canonical 4-column row shape and every existing section's parsing MUST be byte-identical for specs without contract rows.
- **FR-002**: `zfa tdd plan` MUST derive one contract behavior row per method declared in the spec's `## Layer Contracts` section. The row id MUST be `contract:<L><n>` where the letter categorizes the declared surface: an interface whose name ends with `UseCase` is a usecase (`contract:U<n>`), one ending with `Controller` is a controller method (`contract:C<n>`, matching Presentation-layer controller naming), and every other declared interface is an entity-method contract (`contract:A<n>` — the entity/data contract surface, the acceptance substrate). Numbering is per category in declaration order. The rows MUST render under `## Contract loop: contract behaviors`, MUST be preserved across re-planning (state carried like the ffi lane), MUST default engine-side in a lane split (overridable by a lane declaration), and MUST NOT participate in the routing provenance walk, the coverage gate, or the traceability matrix (additive: spec-prose semantics untouched).
- **FR-003**: `zfa tdd gen <contract id>` MUST produce the contract pair: a test file enumerating the contract's declared method cases (one `test` per case, asserting the case is satisfied) and a compilable subject harness carrying the case table with per-case seams. The artifacts MUST be namespaced per feature with the `contract:` id sanitized to a portable file segment (`contract_a1`), registered in the artifact registry, and covered by proof receipts exactly like every other gen pair. Idempotency, ownership, and the staleness contract apply unchanged.
- **FR-004**: `zfa tdd verify-red` on a contract-kind behavior whose target test fails through an assertion MUST report the `blocked` classification (`verify-red: behavior=<id> classification=blocked certified=false feature=<f>`), exit non-zero, write NO red evidence to the cycle log, and persist the receipt `.zfa/receipts/contract-blocked.<id>.json` (id sanitized per the portable receipt naming rules) carrying the behavior, feature, classification, failing cases, and command transcript digest. Non-assertion failure classes (compile-error, load-error, runner-error, …) keep their existing classifications — only an honest failing contract case is BLOCKED.
- **FR-005**: `zfa tdd run` MUST treat a verify-red step outcome of `blocked` as a distinct stop: `result=blocked`, `stopped_at=<id>:verify-red`, exit non-zero, and the behavior stays at its pre-make state (the cycle is blocked from proceeding to GREEN). The `StepRunner` MUST surface the child's `classification=blocked` summary token as the step outcome.
- **FR-006**: The corpus-economics gap ledger MUST carry an optional `severity` field on gap entries (backward-compatible JSON: absent on legacy entries, appended after the existing keys so committed ledgers stay byte-stable), the corpus run MUST stamp `severity=contract` on gaps whose stopped behavior is a contract behavior (or whose outcome token is `blocked`), and `GapLedgerTotals` MUST rank contract-severity gaps first among blocking/open gaps and expose their count. `zfa tdd corpus status` MUST print the severity on severity-carrying gaps.

### Key Entities

- `BehaviorKind.contract` (extended enum, `lib/src/plugins/tdd/models/behavior.dart`) — the new kind; rides the existing `Behavior`/`BehaviorRow` models.
- `ContractDeclaration` (new parse result, `lib/src/plugins/tdd/services/spec_parser.dart`) — one declared interface: category (entity/controller/usecase), interface name, method signatures, spec line.
- `ContractTestWriter` / `ContractSubjectWriter` (new pair, `lib/src/plugins/tdd/services/contract_writer.dart`) — the gen pair for the contract kind; same `write` signatures as every writer pair.
- `ContractBlockedReceipt` (new service, `lib/src/plugins/tdd/services/contract_blocked_receipt.dart`) — writes the `contract-blocked.<id>.json` receipt through the existing `ReceiptStore`.
- `GapSeverity` (new enum, `lib/src/plugins/tdd/models/corpus_ledger.dart`) — `contract` > `standard` ranking for gap entries.

## Success Criteria *(mandatory)*

- **SC1**: `zfa tdd plan 004-login-ui` (a spec declaring Layer Contracts) emits `contract:A1` — an entity method contract — in the engine plan, and the reader resolves the rows as contract kind.
- **SC2**: `zfa tdd gen contract:A1` produces a contract test that enumerates method cases.
- **SC3**: A deliberately unimplemented method causes a `BLOCKED` (not `RED`) verdict — `classification=blocked`, no red evidence, the `contract-blocked.<id>.json` receipt on disk — and the run-cycle stop is `result=blocked` before GREEN.
- **SC4**: The corpus ledger stamps and ranks contract failures as highest-severity gaps.
- **SC5**: `dart analyze` zero new issues; `dart format .` zero diffs; the chunked fast suite green; `tdd/verification.md` written from the real runs.

## Hard Constraints

- The contract kind is additive: existing unit/widget test semantics MUST NOT change (one PR for this spec).
- A spec without Layer Contracts MUST plan byte-identically to the pre-1007 binary.
- The BLOCKED verdict exists only on the contract lane; every non-contract classification path is untouched.
