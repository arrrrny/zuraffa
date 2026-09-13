**Template Version**: `zuraffa-1.0`

# Tasks: 1536-named-param-syntax-parsing

**Input**: Design documents from `specs/1536-named-param-syntax-parsing/`

**Prerequisites**: plan.md (required), spec.md (required)

Dependency-ordered, MVP-first. Every behavior task carries a
`[behavior: <id>]` marker and is MANDATORY (never skippable) — the test
must be written and certified red BEFORE its implementation task.

## Phase 1 — Foundational (grammar, no rendering)

- [ ] T001 In `lib/src/plugins/tdd/models/routing.dart`, add the
      shared top-level parameter-token splitter: split at commas NOT
      nested inside `{...}` / `[...]` / `(...)` / `<...>`; tokens keep
      their grouping characters verbatim (a named group survives as ONE
      token). Document the supported grammar at the parse site
      (FR-006): positional `Type name` (or `Type`) pairs,
      optional-positional `[...]` groups, named `{...}` groups
      (`{Type name, ...}` or `{name, ...}`).
- [ ] T002 In `lib/src/plugins/tdd/models/routing.dart`, use the shared
      splitter in `Signature.parse` (FR-001) and refuse a token with
      stray/unbalanced grouping characters with a [FormatException]
      naming the supported grammar + `--> fix:` remedy (FR-005).

## Phase 2 — Behavior: named-group parsing survives the round trip (US1)

- [ ] T003 [behavior: U-1536-1] RED first: in
      `test/plugins/tdd/issue_1536_named_param_syntax_test.dart`, assert
      `Signature.parse('log({level, onRecord}) -> void')` yields ONE
      parameter token, verbatim `{level, onRecord}` (SC-1), and that a
      mixed row (`log(String id, {Object? level}) -> void`) splits into
      `String id` + `{Object? level}`.
- [ ] T004 [behavior: U-1536-2] RED first: same file, assert the
      derived `UnitContractShape` for `log({level, onRecord}) -> void`
      carries two NAMED params with names `level` / `onRecord` (camelCase
      preserved — Defect 2) and type `Object?` (FR-002 / SC-2), that a
      two-word group token keeps the `Type name` split
      (`{AuthRequest request}` → type `AuthRequest`, name `request`),
      and that `Signature.toString()` re-renders the declared text.
- [ ] T005 [behavior: U-1536-3] RED first: same file, assert the
      refusal: a stray-brace parameter row
      (`log({level, onRecord) -> void`) throws [FormatException] whose
      message names the grammar and carries `--> fix:` (FR-005 / SC-4);
      a FUNCTION-layer spec row carrying it refuses via
      `SpecParser.parseContractRows` with a [StateError] naming the row
      and spec line.
- [ ] T006 Implement `UnitContractParam.named` + the named-group
      expansion in `UnitContractShape.of` / `ofResolved` (FR-002): a
      single-identifier group token is a NAME with renderable type
      `Object?`; multi-word keeps `Type name`; positional tokens keep
      the legacy single-identifier = TYPE reading; `_defaultParamName`
      keeps an already lower-first identifier verbatim (FR-004). GREEN
      for T003/T004/T005.

## Phase 3 — Behavior: the generated pair renders named (US2)

- [ ] T007 [behavior: U-1536-4] RED first: assert the subject writer
      renders `void subject_u3({Object? level, Object? onRecord})`
      (named group AFTER positionals; SC-2) for a named-param contract,
      and the byte-identical legacy form for a positional contract
      (`login(AuthRequest) -> User` shape → positional params, SC-6).
- [ ] T008 [behavior: U-1536-5] RED first: assert the paired unit
      test's capture site reads
      `subject.subject_u3(level: _arg0(), onRecord: _arg1())` (named
      arguments; SC-3), the `_argN()` helper messages carry whole
      declared types (no `{level` fragment anywhere), scalar named
      params pass their representative literal (`level: 'sample'` form),
      and a positional contract's capture site is unchanged.
- [ ] T009 Implement the shared param-list renderer on
      `UnitContractShape` (positional params first, named group as a
      trailing `{...}` block), use it from
      `SubjectWriter._renderContractUnitSubject` and
      `func_command._renderScaffolded` (FR-003), and emit named
      arguments (`name: expr`) in
      `behavior_test_writer._captureInvocation`. GREEN for
      T007/T008.

## Phase 4 — Integration & verification

- [ ] T010 Full-suite verification: `dart analyze` (changed files, no
      new warnings), the touched existing suites
      (`unit_contract_shape_1489_test.dart`, `subject_writer_test.dart`,
      `routing_resolver_test.dart`, behavior_test_writer suites) green,
      `dart format` clean; record red evidence + results in
      `specs/1536-named-param-syntax-parsing/tdd/verification.md`.
