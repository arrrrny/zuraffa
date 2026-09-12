# Bug Assessment: wire cannot wire contract-derived subjects (#1500)

- **Slug**: 1500-wire-contract-derived-subject
- **Created**: 2026-09-11
- **Source**: https://github.com/arrrrny/zuraffa/issues/1500
- **Verdict**: valid
- **Severity**: high (the entity pipeline is unreachable for every
  contract-derived behavior)

## Report (summarized from the issue, verified in a scratch fixture)

`zfa tdd wire <id>` matches only the legacy no-arg stub regex
`^(int|void)\s+name\(\)\s*=>\s*throw UnimplementedError\(`. Every
contract-derived subject (issue #1259) renders a different shape — declared
parameters and a degraded `Object?` return
(`Object? subject_u2(String title) => throw UnimplementedError(...)`) — so
wire classifies it as an unrecognized shape and refuses with exit 1. The
entity create → mock create → wire → build pipeline can never complete for
a contract-derived behavior.

## Root cause

wire predates contract-derived subjects (#1259) and declared-signature
routing (feature 071). Two stale assumptions:

1. `_stubSignature` assumes the only stub gen writes is the legacy no-arg
   `int|void name()` arrow-throw. SubjectWriter's contract-unit renderer
   emits `${shape.returnType} $target($params) => throw
   UnimplementedError(...)` — any return type, any parameter list.
2. `_defaultBodyFor` assumes the wired dummy is a type-correct literal.
   For a declared entity return the stub's renderable type degrades to
   `Object?`; a literal path bottoms out in `return null as Task;` — a
   runtime cast error — while the pipeline already generated the value one
   step earlier (`zfa mock create --name Task` writes
   `TaskMockData.sampleTask` / `.sampleList`), which wire never consults.

## Reproduction (verified)

A fixture declaring `TaskStore: create(String title) -> Task` with the
SubjectWriter-shaped stub `Object? subject_u2(String title) => throw
UnimplementedError('subject_u2 not implemented: create(String title) ->
Task')` refuses: `carries an UnimplementedError in an unrecognized shape`,
exit 1. See `red-evidence.md`.

## Remediation (wire_command.dart only)

1. `_stubSignature` accepts every stub shape SubjectWriter emits — any
   return type (scalar, entity, generic, nullable), any parameter list —
   while staying pinned to the single-line arrow-throw form so hand-owned
   shapes (block bodies, the FFI harness's wrapped seams) keep the
   U-W5-style refusal. Group 3 captures the declared parameter list
   verbatim.
2. wire resolves the DECLARED signature through the same machinery gen
   used (#1259 / feature 071): `DeclaredRouting.declaredSignatureFor`
   (test-list traces → spec contract rows) → `UnitContractShape.of`, with
   a fallback to the stub's own provenance header
   (`//     create(String title) -> Task`) when the spec artifacts are
   absent. The declared return — never the degraded `Object?` — becomes
   the wired return, gated by a type-token plausibility check so
   prose-adjacent header text can never render a non-type.
3. Entity-shaped returns bind to the generated mock data:
   `<E>MockData.sample<E>` for `E`/`E?`, `.sampleList` for
   `List<E>`/`Iterable<E>`, `.sampleList.toSet()` for `Set<E>` — plus the
   `package:` import of the mock-data file. Scalars keep the type-correct
   literals (`return false;`, `return 0;`, `return '<name>';`, `0.0`,
   `const <String>[]`, `const <String, Object?>{}`).
4. A missing mock-data file is an honest misfire-stop naming the skipped
   pipeline step (`zfa mock create --name <Entity>`); the subject is left
   untouched.
5. The wired signature keeps the declared parameters verbatim (arity,
   names, renderable types) — the paired immutable test keeps compiling.

## Constraints honored

- ONLY `lib/src/plugins/tdd/commands/wire_command.dart` changed; gen,
  SubjectWriter, and the state machine are untouched (verified by the
  diff and by the 15 pre-existing wire pins plus the gen/func suites
  staying green).
- Scalar / entity / generic / nullable returns all covered (U-1500a–g).
- Legacy no-arg stubs byte-compatible (U-1500h; U-W1/U-920 series).
- `dart analyze` on the changed files: 0 issues.
