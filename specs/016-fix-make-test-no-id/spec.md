# Feature Specification: make --test regenerates tests for id-less entities

**Feature Branch**: `016-fix-make-test-no-id`

**Created**: 2026-08-27

**Status**: Draft

**Input**: User description: "`zfa make <Entity> --test` (regenerate usecase tests on zuraffa-native mocks, replacing mocktail) fails for any entity that has no `id` field and is not a `@ZValueObject` — even though those entities already have working get/update/toggle usecase tests. This blocks the mocktail-removal migration in apps/zikzak_demo: 7 of its test-bearing entities are no-id and cannot be regenerated via zfa (issue #508). The loud no-id failure introduced by #307 runs before plugin dispatch and therefore fires even when the only active plugin is `test`, which is id-neutral."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Regenerate tests for an id-less entity (Priority: P1)

A developer maintains an app whose entity (for example an authentication request described only by email, password and method) deliberately carries no identity field. The usecases and their tests already exist. The developer runs `zfa make <Entity> --test --force` to regenerate the usecase tests (for example as part of migrating them off mocktail). Today the command exits 1 with "the entity has no id field" before any test file is touched; after this feature it exits 0 and rewrites the three per-method test files.

**Why this priority**: This is the exact defect reported in #508 and the only reason the migration is blocked; every other story is a guardrail around it.

**Independent Test**: Run `zfa make AuthRequest --test --force` in apps/zikzak_demo (or an equivalent project) and observe exit 0 plus regenerated test files — no other story is required for this to deliver value.

**Acceptance Scenarios**:

1. **Given** an entity with no id-like field, no `autoId` marker and no value-object annotation, **When** `zfa make <Entity> --test --force` runs, **Then** the command exits 0 and the get/update/toggle test files are (re)written.
2. **Given** such an entity, **When** the regenerated tests are inspected, **Then** every filter/field reference points at a field constant that actually exists on the entity (a representative real field — never a field that does not exist, never an enum-typed field, never an invented `id`).
3. **Given** an id-less entity whose tests previously referenced a non-existent `id` field constant, **When** the tests are regenerated and executed, **Then** the suite passes.

### User Story 2 - Full architecture generation still fails loudly for id-less entities (Priority: P1)

A developer runs full architecture generation (`zfa make <Entity>` with the standard preset, or any request that includes repository/usecase/controller/presenter/datasource plugins) against an entity with no identity. The #307 protection must be preserved: the command must exit 1 with the same "the entity has no id field" diagnostic and the same three remediation hints (add an id field, recreate with --auto-id, mark as value object).

**Why this priority**: The loud failure exists to prevent silently broken generated code; weakening it would regress #307/#321 and reintroduce the enum-typed-id bugs those issues fixed.

**Independent Test**: Run `zfa make AuthRequest --force` (id-dependent plugins active) and assert exit 1 plus the unchanged #307 message and hints.

**Acceptance Scenarios**:

1. **Given** an id-less entity, **When** `zfa make <Entity> --force` runs with id-dependent plugins active (repository, usecase, controller, presenter, datasource, ...), **Then** it exits 1, prints "the entity has no id field" and the three remediation hints, and no architecture files are written.
2. **Given** an id-less entity, **When** an explicit `--id-field` is passed with id-dependent plugins active, **Then** the loud failure still fires (the flag cannot conjure an identity — #321 contract).

### User Story 3 - Id-bearing entities are unaffected (Priority: P2)

A developer regenerates tests for an entity that *does* have an id (for example PriceAlert, the known-good control from the issue). Behaviour must be byte-for-byte identical to today: tests regenerate, reference the resolved id field, and pass.

**Why this priority**: Guards against over-application of the fix in the opposite direction; must be proven but requires no new behaviour.

**Independent Test**: Run `zfa make PriceAlert --test --force` and the PriceAlert test suite; both must succeed exactly as before.

**Acceptance Scenarios**:

1. **Given** an entity with a real `id` field, **When** `zfa make <Entity> --test --force` runs, **Then** it exits 0 and the tests reference the existing id field constant.
2. **Given** the same entity, **When** its tests execute, **Then** they pass.

### User Story 4 - The seven blocked demo entities migrate (Priority: P2)

A developer completes the mocktail migration for the seven named zikzak_demo entities: auth_request, barcode, device_info, grocery_price_comparison, grocery_price_result, metric_detail, store_price. Each regenerates its get/update/toggle tests through `zfa make <Entity> --test --force`, and the resulting suites pass.

**Why this priority**: This is the aggregate outcome the issue is really about; it depends on User Story 1 but proves it at scale.

**Independent Test**: Loop the regeneration command over the seven entities, then run the app's test suite and count pass/fail.

**Acceptance Scenarios**:

1. **Given** the seven id-less entities with pre-existing usecases, **When** each is regenerated with `--test --force`, **Then** every command exits 0.
2. **Given** the regenerated tests, **When** the app test suite runs, **Then** all of those entities' tests pass.

### Edge Cases

- An id-less entity whose *first* declared field is an enum (e.g. ChatMessage.role): the representative query field must skip enum-typed fields rather than regressing to the pre-#307 first-field fallback.
- An id-less entity with no usable scalar field at all: regeneration must still not crash; it proceeds without inventing a field.
- A value object (`@ZValueObject`): unchanged behaviour — root plugins are dropped with the notice; no id requirement applies.
- `--no-entity` flows: the resolver is skipped entirely; unchanged behaviour.
- An explicit `--query-field` passed by the user: the automatic representative-field resolution must not override it.
- Only id-neutral plugins requested (test, mock): no loud failure, regardless of combination.
- Mixed requests (e.g. `--test` together with `usecase`): the id-dependent plugin is present, so the loud failure fires.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa make <Entity> --test --force` MUST succeed (exit 0, tests regenerated) for any entity that has no id-like field and is not a value object.
- **FR-002**: The no-id loud failure (message, three remediation hints, exit 1) MUST fire exactly as before whenever at least one id-dependent plugin (repository, usecase, controller, presenter, datasource, and other plugins whose generated signatures embed an id) is active.
- **FR-003**: The id-dependent plugin ids MUST be declared as one named constant (a single greppable set), not an inline magic list at the call site.
- **FR-004**: On the id-neutral path the system MUST resolve the query/filter key to a representative REAL field of the entity — a field that exists in the entity source.
- **FR-005**: The representative field selection MUST NOT choose an enum-typed field and MUST NOT invent a synthetic `id`.
- **FR-006**: An explicitly provided `--query-field` MUST take precedence over the automatic representative-field resolution.
- **FR-007**: Id-bearing entities and value objects MUST behave exactly as before this change.
- **FR-008**: The regenerated tests for id-less entities MUST reference an existing field constant so the emitted code compiles and the tests pass.
- **FR-009**: A regression test MUST cover both directions: `--test`-only on an id-less entity succeeds, and an id-dependent plugin request on the same entity still throws the #307 error.

### Key Entities *(include if feature involves data)*

- **MakeCommand entity resolution**: the pre-dispatch step that resolves the entity's identity and currently throws `MakeCommandException` for id-less entities regardless of active plugins.
- **Id-dependent plugin set**: the named registry of plugin ids whose generated output embeds an identity field in signatures.
- **Representative query field**: a real, non-enum field of the entity used as the query/filter key on the id-neutral path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All seven named zikzak_demo entities (auth_request, barcode, device_info, grocery_price_comparison, grocery_price_result, metric_detail, store_price) regenerate via `zfa make <Entity> --test --force` with exit 0.
- **SC-002**: The regenerated get/update/toggle tests for those seven entities all pass when the app test suite runs.
- **SC-003**: No regenerated test file for the seven entities references a field constant that does not exist on its entity.
- **SC-004**: `zfa make <Entity> --force` (id-dependent plugins active) on an id-less entity still exits 1 with the exact #307 message and the same three remediation hints, and writes no files.
- **SC-005**: The known-good id-bearing control entity (PriceAlert) still regenerates its tests and its suite passes.
- **SC-006**: The zuraffa framework's own fast test suite (`dart test`) and `dart analyze` stay green, with any pre-existing unrelated failures explicitly called out rather than silently absorbed.
- **SC-007**: The mocktail-removal migration for the seven entities is unblocked end-to-end: with the maintainer's in-flight test-builder rewrite (which emits zuraffa-native mocks instead of mocktail — uncommitted work deliberately NOT part of this change, per the mergeability constraint) stacked on top of this fix, regenerating the seven entities leaves no mocktail imports in their test files. Within this change alone the criterion is verified as: regeneration exits 0 and the regenerated files reference real field constants; the import swap itself is owned by the builder rewrite.

## Assumptions

- The `apps/zikzak_demo` project is not part of the zuraffa repository itself; verification of SC-001/SC-002 uses an equivalent local reproduction that mirrors its state (id-less entities with pre-existing get/update/toggle usecases and repositories), with the equivalence documented.
- Whether the regenerated tests still import mocktail is decided by the (separately maintained, uncommitted) test-builder work; this feature only unblocks regeneration and must keep its diff tightly scoped to the identity gating so it stays mergeable with that work.
- The loud #307 diagnostic text (message + three hints) is contract and must not change.
- Pure Dart, no Flutter SDK dependency in the CLI path.
