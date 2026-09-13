---
feature: 1536-named-param-syntax-parsing
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 60288f4b
updated_at: 60288f4b
suite_baseline: green
---

# Test List: 1536-named-param-syntax-parsing

`loop: inside-out` — the surface is a pure parsing/rendering contract
inside the generator (no user-visible outer loop beyond the generator's
own output); the behaviors below close at the unit tier against the
parse/shape/render seams.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | `Signature.parse` keeps a `{...}` named group as ONE parameter token with its braces (`{level, onRecord}`), never two brace-dangling positional tokens | AC-1 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| A2 | the generated subject renders named parameters in a trailing `{...}` group (`void subject_u3({Object? level, Object? onRecord})`), names camelCase-preserved | AC-2 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| A3 | the paired test passes named arguments (`subject.subject_u3(level: _arg0(), onRecord: _arg1())`) and no generated line carries a dangling `{level` fragment | AC-3 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| A4 | a names-only group treats each single identifier as a NAME with `Object?` type; a two-word group token keeps the `Type name` split | AC-4 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| A5 | a stray/unbalanced-brace parameter row refuses with a named remedy (grammar + `--> fix:` + row/spec line) instead of degrading | AC-5 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| A6 | existing positional rows render byte-identically (subject, names, args) — no existing row breaks | AC-6 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | the parameter text splits at top-level commas only; nested `{}`/`[]` commas never split a token (FR-001) | FR-001 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| U2 | the shape expands a named-group token into named `UnitContractParam`s; positional tokens keep the legacy single-identifier = TYPE reading (FR-002) | FR-002 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| U3 | subject writer + `zfa tdd func` scaffold render the grouped form via ONE shared renderer; the test writer emits named args at the capture site (FR-003) | FR-003 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| U4 | name derivation keeps an already lower-first camelCase identifier verbatim (`onRecord` stays `onRecord`); upper-first type-derived names keep the legacy output (`AuthRequest` → `authrequest`) (FR-004) | FR-004 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |
| U5 | a stray-brace token throws [FormatException] naming the supported grammar (positional `name(Type)` pairs, named `{a, b}` groups) with a `--> fix:` remedy; a FUNCTION-layer spec row refuses via `parseContractRows` naming row + spec line (FR-005, FR-006) | FR-005, FR-006 | example | PENDING | `test/plugins/tdd/issue_1536_named_param_syntax_test.dart` |

## Invariants and edge cases still to place

- Mixed row `log(String id, {Object? level, Object? onRecord}) -> void`:
  positional token first, named group last, both whole (covered by U1).
- Optional-positional `[int a, int b]` must not corrupt (splitter
  respects `[]`); rendering of `[...]` groups is NOT a gen surface
  (out of scope below) — only non-corruption at parse time (U1).
- Generic types inside a group (`{Map<String, int> table}`) survive the
  inner split (U1).
- `Signature.toString()` re-renders the declared text byte-identically
  (provenance headers stay truthful) (U1).

## Out of scope

- Void-return capture compile errors (`return_of_invalid_type_from_closure`
  / `use_of_void_result`): companion issue #1538 owns the void-returning
  guard; this feature never asserts a `-> void` pair compiles at run.
- The contract test lane and `DependencySignature` grammar: separate
  parser, separate lane, untouched by constraint.
- Optional-positional `[...]` generation: the splitter preserves the
  tokens; gen renders named groups only.
- End-to-end `zfa tdd gen` filesystem runs: the writer seams are
  deterministic pure functions of the shape; existing gen-level suites
  (bug_1363, 1489, subject_writer) pin the file plumbing.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
