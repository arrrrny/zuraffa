# Verification: 1536-named-param-syntax-parsing

**Branch**: `feat/1536-named-param-syntax-parsing` | **Date**: 2026-09-13 | **Audited against**: spec.md SC-1…SC-5, tasks.md T001–T010

## Phase 1 — Every behavior is on the list and green

- test-list: 6 acceptance (A1–A6) + 5 unit (U1–U5) behaviors, all
  `DONE`, every `traces` value resolving to a real AC/FR id in
  `spec.md` (mechanical check passed — AC-1…AC-6 and FR-001…FR-006 all
  covered, no orphan rows, no duplicate observable results).
- cycle-log: 4 cycles, each with a red block recorded BEFORE its
  implementation (append-only; corrections are entries, never edits).

## Phase 2 — The reds were honest

The red evidence (cycle-log, `commit 60288f4b` state) reproduces the
issue's defects VERBATIM, not merely failing assertions:

- Defect 1: `Expected: ['{level, onRecord}'] / Actual: ['{level',
  'onRecord}']` — the brace-ignorant comma split, byte-identical to the
  issue's `(declared param 0: {level)` repro.
- Defect 2: `Expected: ['level', 'onRecord'] / Actual: ['level',
  'onrecord']` — the camelCase mangle, byte-identical to the issue's
  `void subject_u3(Object? level, Object? onrecord)`.
- The cascade the mangle produces (`{AuthRequest request}` →
  `authrequestRequest`) and the positional capture
  (`subject.subject_u3(_arg0(), _arg1())`) both red before the fix.
- The refusal cases red as silent-parse (`returned
  Signature:<log(}level) -> void>`) — no refusal existed.

RED tally at `60288f4b` (with the additive `named` model field so the
suite compiles): **4 passed / 18 failed**, every failure on an
assertion for the right reason.

## Phase 3 — The greens are real and the suite is green

| Check | Command | Result |
| ----- | ------- | ------ |
| Behavior suite | `dart test test/plugins/tdd/issue_1536_named_param_syntax_test.dart` | 22 passed, 0 failed |
| Touched suites (direct) | `behavior_test_writer_test`, `spec_parser_test`, `subject_writer_test` + the 1536 suite | 77 passed, 0 failed |
| Existing pinned suites | `unit_contract_shape_1489_test`, `routing_resolver_test`, `function_contracts_parsing_test` | included above, green |
| Full tdd plugin tree (187 files, 3 shards) | `dart test` per shard, kernel-cache cleanup between | 541 + 559 + 683 = **1783 passed, 0 failed** |
| Suite outside the plugin tree touching the writers | `dart test test/cli/writers/tdd/spec_template_writer_test.dart` | 5 passed, 0 failed |

## Phase 4 — Rubric: test power (deliberate-mutant sampling)

No mutation tool is wired for Dart (profile); deliberate-mutant sampling
per the rubric:

- Mutant M1: remove `<`/`>` from the splitter's opener set (generics no
  longer depth-tracked). Result: `a generic type inside the group
  survives the split` FAILS — mutant killed, the suite detects the
  regression class. Reverted (`git checkout`), suite re-green (22/22).
- The RED evidence itself is the second power sample: 18 honest reds
  against the pre-fix binary.

## Phase 5 — Gates

| Gate | Result |
| ---- | ------ |
| `dart analyze` over every `.dart` file the branch touches (`git diff --name-only master...HEAD`) | **No issues found** |
| `dart analyze` full repo, with-change vs stash-baseline | 112 issues == 112 issues — **zero new warnings** (pre-existing info-level lint debt elsewhere) |
| `dart format` over the changed files (`--set-exit-if-changed`) | 0 changed — format-clean |
| Verify protocol cleanup (`rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`) | done before and after the battery |
| Byte-compatibility (SC-6) | `format(String input) -> String` renders `String subject_u6(String input)` + `subject.subject_u6(r'sample')`; `login(AuthRequest) -> User` keeps `authrequest` — pinned by the 1536 suite AND the pre-existing 1489/1259/1500 suites, all green |

## Success criteria audit (spec.md)

- **SC-1** — `Signature.parse('log({level, onRecord}) -> void')`
  yields exactly `['{level, onRecord}']`: PASS (U1 case 1).
- **SC-2** — two named params `level`/`onRecord`, type `Object?`,
  subject renders `({Object? level, Object? onRecord})`: PASS (U2,
  U3 subject case).
- **SC-3** — capture site `subject.subject_u3(level: _arg0(),
  onRecord: _arg1())`, no `{level` fragment: PASS (U3 test cases).
- **SC-4** — stray-brace row throws the named remedy; FUNCTION row
  refuses via `parseContractRows` naming row + spec line: PASS (U5).
  Plan-time refusal rides the existing machinery (`plan_command`
  parses declared rows before any artifact write; gen/wire refuse
  through `DeclaredRouting`).
- **SC-5** — existing suites green + no new analyzer warnings: PASS
  (1783 + 77 + 5 greens; 112 == 112).

## Out of scope (recorded)

Void-return capture diagnostics (`return_of_invalid_type_from_closure`,
`use_of_void_result`) — companion issue #1538. The 1536 suite never
asserts a `-> void` pair compiles at run; the declared-void rendering
itself (`void subject_u3({...})`) is covered and correct.

## Verdict

**CERTIFIED GREEN.** The feature's behaviors exist, are traced, were
red for the right reasons, are green now, the full scoped suite is
green, the analyzer gate reports zero new warnings, and one deliberate
mutant was killed by the suite.
