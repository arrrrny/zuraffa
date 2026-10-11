# Cycle Log: 1536-named-param-syntax-parsing

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/services/unit_contract_shape_1489_test.dart test/plugins/tdd/subject_writer_test.dart test/plugins/tdd/services/routing_resolver_test.dart` -> 45 passed, 0 failed
- static: `dart analyze` (full repo) -> 112 issues (pre-existing info-level; changed-file subset: No issues found)
- commit: `60288f4b` (branch `feat/1536-named-param-syntax-parsing`)
- recorded: cycle 0, before any change
- note: full-repo analyze re-measured at the stash baseline immediately
  before the implementation commit — 112 issues both before and after the
  fix (zero new warnings, SPEC SC-5).

## Cycle 1: U1 — the named group survives as ONE token (FR-001, AC-1)

- test: `test/plugins/tdd/issue_1536_named_param_syntax_test.dart`
  `1536 AC-1/FR-001: the named group survives as ONE token` (new, 6 cases)
- red: `dart test test/plugins/tdd/issue_1536_named_param_syntax_test.dart`
  -> `Expected: ['{level, onRecord}'] / Actual: ['{level', 'onRecord}']`
  (the issue's Defect 1, reproduced verbatim); the typed group split to
  `['{Object? level', 'Object? onRecord}']`, the generic-in-group case
  split to `['{Map<String', 'int> table}']`, and the optional-positional
  group split to `['int x', '[int a', 'int b]']` (1 failed of the group's 6;
  4 passed — the single-token-group cases today's bare split handles by
  accident, kept as regression guards, plus the toString round trip)
- green: `routing.dart` — `Signature.parse` now splits at TOP-LEVEL commas
  only via the shared `splitParameterTokens` walker (`{} [] () <>` depth
  tracked; groups keep their braces; `isWellFormedParameterToken` +
  `parameterSyntaxRemedy` refuse stray grouping characters). Whole group
  green (22/22 with the later cycles' wiring). Suite `dart test
  test/plugins/tdd/issue_1536_named_param_syntax_test.dart` -> 22 passed
- refactor: none needed — the splitter is ONE top-level function consumed
  by `Signature.parse` and the shape's inner group split
- commit: `339190a0`

## Cycle 2: U2/U4 — the shape expands named params; camelCase preserved (FR-002/FR-004, AC-2/AC-4)

- test: same file, `1536 AC-4/FR-002: the shape expands named params` +
  `1536 AC-6/FR-004: camelCase is preserved, legacy rows unchanged` (new,
  7 cases)
- red: -> `Expected: ['level', 'onRecord'] / Actual: ['level', 'onrecord']`
  (the issue's Defect 2, reproduced verbatim); the two-word group token
  mangled to `authrequestRequest`; every named flag false; the
  lower-first positional type `onRecord` derived the name `onrecord`
- green: `unit_contract_shape.dart` — `UnitContractParam.named` (additive,
  default false), the ONE `_expandParamTokens`/`_paramPartsOf` grammar
  (single identifier inside a group = declared NAME with the `Object?`
  degradation; two words keep `Type name`), consumed by `of` AND
  `ofResolved`; `_defaultParamName` keeps a lower-first head word
  verbatim while upper-first heads keep the legacy full-lowercase
  (`authrequest`). Whole suite green
- refactor: the token loop in `of` and the candidate walk in `ofResolved`
  collapsed onto the shared expansion — the duplicated whitespace-split
  logic from #1259/#1489 became one grammar
- commit: `339190a0`

## Cycle 3: U3 — the generated pair renders named (FR-003, AC-2/AC-3/AC-6)

- test: same file, `1536 AC-2/AC-3/FR-003: the generated pair renders
  named` (new, 6 cases)
- red: -> `Expected: contains 'void subject_u3({Object? level, Object?
  onRecord}) =>'` / actual subject rendered the positional
  `Object? level, Object? onrecord)` form; the paired test's capture was
  positional `subject.subject_u3(_arg0(), _arg1())`; `onrecord` present
  in the stub; scalar named arg case failed
- green: `UnitContractShape.renderParameterList` (positional first, named
  group as ONE trailing `{...}` block) adopted by `SubjectWriter` AND
  `func_command._renderScaffolded` (one renderer, two call sites);
  `behavior_test_writer._captureInvocation` emits named arguments
  (`level: _arg0(), onRecord: _arg1()`) with scalar named params passing
  their representative literal. Whole suite green
- refactor: the two per-writer `params.map(...).join(', ')` renderings
  replaced by the shared renderer — no call-site drift possible
- commit: `339190a0`

## Cycle 4: U5 — unparseable syntax refuses with a named remedy (FR-005/FR-006, AC-5)

- test: same file, `1536 AC-5/FR-005: unparseable syntax refuses with a
  named remedy` (new, 3 cases)
- red: -> stray-brace row parsed silently (`returned
  Signature:<log(}level) -> void>`), the FUNCTION-layer spec row produced
  a ContractRowDecl instead of refusing
- green: `Signature.parse` throws `FormatException(parameterSyntaxRemedy(`
  `token))` for stray/unbalanced grouping; `parseContractRows` FUNCTION
  rows embed the parse error's own remedy in the existing StateError
  (row name + raw text + spec line + `--> fix:`) while the
  missing-`-> Return` refusal keeps its legacy message byte-for-byte.
  Plan-time refusal confirmed by machinery: `plan_command` parses
  declared rows before any artifact write (`plan_command.dart` round-2
  fix 3a block); gen/wire refuse through `DeclaredRouting`.
  Whole suite green
- refactor: none
- commit: `339190a0`

## Notes and deviations

- The `UnitContractParam.named` model field landed BEFORE the behavior
  tests could compile (the honest-RED requirement: behavior tests must
  fail on ASSERTIONS, not on missing API). It is purely additive
  (default `false`), changes no output, and is recorded here as
  foundational vocabulary per the 991 convention (tasks T006's first
  half).
- One test-authoring defect was fixed during the green step (not a code
  defect): the SC-6 legacy-pin expected `subject_u6('sample')` but the
  writer emits the raw-string literal `r'sample'`. The expectation was
  corrected; no source change was involved.
- Full tdd-plugin suite verified in three shards with kernel-cache
  cleanup between them (the runner's `/tmp/dart_test.kernel.*` fills the
  disk on a single 187-file run): 541 + 559 + 683 = 1783 passed, 0
  failed, plus `spec_template_writer_test.dart` (5) outside the plugin
  tree.
- `dart format` applied to the new test file; all changed files
  format-clean (`--set-exit-if-changed`).
