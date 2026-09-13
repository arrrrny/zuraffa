**Template Version**: `zuraffa-1.0`

# Spec: 1536-named-param-syntax-parsing

## Overview

A declared Layer Contract row that uses Dart named-parameter syntax
(e.g. `Logger: log({level, onRecord}) -> void`) makes `zfa tdd gen` emit
a subject + test pair that does not compile, violating FR-011 ("minimal
compilable stub"). Two defects compound:

1. **Brace-ignorant comma split** — `Signature.parse`
   (`lib/src/plugins/tdd/models/routing.dart`) splits the parameter text
   on every bare comma, so the named group `{level, onRecord}` parses as
   two POSITIONAL parameters with the braces dangling inside the tokens
   (`{level`, `onRecord}`). Named-parameter syntax silently degrades to
   a positional list.
2. **camelCase mangling** — `UnitContractShape._defaultParamName`
   lowercases the whole first word of a type-derived name, so the
   mangled token `onRecord}` renders the subject parameter as
   `onrecord`.

The generated pair is broken end to end:

```dart
// Subject (positional, mangled):
void subject_u3(Object? level, Object? onrecord) => ...

// Test (dangling declared type in the helper message):
Object? _arg0() => throw UnimplementedError('... (declared param 0: {level)');
final result = (() {
  try {
    return subject.subject_u3(_arg0(), _arg1());  // positional; void return!
  } on UnimplementedError catch (error) {
    return error;
  }
})();
// Analyzer: return_of_invalid_type_from_closure + use_of_void_result
```

This spec remediates by making the contract-row grammar PARSE Dart named
parameters and render them as named arguments (Option A), and by
REFUSING genuinely unparseable parameter syntax with a named remedy
instead of emitting a pair that can only die at verify-red (Option B's
refusal, riding the existing malformed-declaration machinery). The
void-return capture errors belong to the companion fix (#1538,
void-returning guard) and are intentionally out of scope.

## Acceptance Scenarios

1. **Given** a Layer Contract row declaring named parameters
   (`log({level, onRecord}) -> void`), **When** the contract row is
   parsed, **Then** the named group survives as ONE parameter token with
   its braces (`{level, onRecord}`) — never two brace-dangling
   positional tokens.
   **Type**: acceptance
2. **Given** a parsed named group, **When** `zfa tdd gen` renders the
   subject signature, **Then** the named parameters render inside a
   `{...}` group AFTER any positional parameters
   (`void subject_u3({Object? level, Object? onRecord})`), with the
   declared parameter names preserved camelCase (`onRecord`, never
   `onrecord`).
   **Type**: acceptance
3. **Given** a parsed named group, **When** the paired unit test is
   written, **Then** the capture site passes named arguments
   (`subject.subject_u3(level: _arg0(), onRecord: _arg1())`) and the
   `_argN()` helper messages name whole declared types — no dangling
   `{level` fragment anywhere in the generated source.
   **Type**: acceptance
4. **Given** a named group whose tokens are names only (`{level,
   onRecord}`), **When** the shape is derived, **Then** each
   single-identifier token is treated as a declared parameter NAME with
   the `Object?` renderable type (Dart named parameters always carry a
   name); a two-word token inside the group (`{AuthRequest request}`))
   keeps the existing `Type name` split.
   **Type**: acceptance
5. **Given** a contract row whose parameter text carries stray or
   unbalanced grouping characters (`log({level, onRecord) -> void`),
   **When** the row is parsed on a FUNCTION-layer row, **Then** the
   parse refuses with a named remedy (the supported grammar, a
   `--> fix:` line, and the row/spec line) instead of silently
   degrading — the same errors-are-an-API contract the missing
   `-> Return` refusal already honors, so plan and gen both stop before
   any artifact is written.
   **Type**: acceptance
6. **Given** every existing positional-parameter contract row
   (`login(AuthRequest) -> User`, `format(String input) -> String`,
   mixed rows), **When** the pair is generated, **Then** the rendered
   subject signature, parameter names, and representative arguments are
   byte-identical to the pre-fix output — no existing row breaks.
   **Type**: acceptance

## Functional Requirements

- **FR-001**: `Signature.parse` MUST split the declared parameter text
  at top-level commas only: a comma inside `{...}` (named group) or
  `[...]` (optional positional group) MUST NOT split the token. A named
  group survives as ONE parameter token that keeps its braces.
- **FR-002**: `UnitContractShape` MUST expand a named-group token into
  individual named parameters. Inside a group a single-identifier token
  is a parameter NAME whose renderable type is `Object?`; a multi-word
  token keeps the existing `Type name` split. Positional tokens keep the
  existing behavior byte-for-byte.
- **FR-003**: The subject writer MUST render named parameters inside a
  `{...}` group placed after all positional parameters; the paired test
  writer MUST pass named arguments (`name: expr`) for named parameters
  and keep positional arguments unchanged. `zfa tdd func`'s declared
  scaffold MUST render the same grouped form (one shared renderer —
  the grammar lives in ONE place, never scattered across call sites).
- **FR-004**: Parameter-name derivation MUST NOT mangle camelCase: a
  single word that is already a lower-first Dart identifier is kept
  verbatim (`onRecord` stays `onRecord`). Upper-first type-derived
  names keep the existing behavior (`AuthRequest` → `authrequest`), so
  no existing positional row's output changes.
- **FR-005**: A parameter token with stray or unbalanced grouping
  characters MUST refuse at parse time with a [FormatException] whose
  message names the supported grammar — positional `name(Type)` pairs
  and named `{a, b}` groups — and a `--> fix:` remedy. On FUNCTION-layer
  rows the existing malformed-declaration machinery surfaces the refusal
  naming the row and spec line at PLAN time (`zfa tdd plan`) and at
  gen/wire time; no compile-error may appear at verify-red minutes
  later.
- **FR-006**: The supported grammar MUST be documented at the parse
  site: positional `Type name` (or `Type`) pairs, optional-positional
  `[...]` groups, and named `{...}` groups (`{Type name, ...}` or
  `{name, ...}`).

## Success Criteria (measurable)

- **SC-1**: `Signature.parse('log({level, onRecord}) -> void')` yields
  exactly one parameter token, verbatim `{level, onRecord}` (FR-001).
- **SC-2**: The derived shape for that row carries two named params
  (`level`, `onRecord`) with type `Object?`, and the subject writer
  renders `({Object? level, Object? onRecord})` (FR-002, FR-003).
- **SC-3**: The paired test's capture site reads
  `subject.subject_u3(level: _arg0(), onRecord: _arg1())` and no
  generated line contains `{level` (FR-003).
- **SC-4**: A stray-brace row
  (`log({level, onRecord) -> void`) on a FUNCTION row throws the named
  remedy; `zfa tdd plan` refuses before writing artifacts (FR-005).
- **SC-5**: The full existing suite for the touched surfaces
  (`unit_contract_shape_1489_test.dart`, `subject_writer_test.dart`,
  `routing_resolver_test.dart`, `behavior_test_writer` suites) stays
  green, and `dart analyze` over the changed files reports no new
  warnings (FR-004 — backward compatibility).

## Out of scope

- The void-return capture errors (`return_of_invalid_type_from_closure`
  + `use_of_void_result` on a `void`-returning subject) — companion
  issue #1538 owns the void-returning guard.
- The contract test lane, the routing state machine, and the parameter
  grammar of non-contract rows (`DependencySignature` keeps its own
  grammar).
- Optional-positional `[...]` RENDERING (the splitter must not corrupt
  it, but gen's subject/test writers render named groups only — no new
  optional-positional generation surface).
