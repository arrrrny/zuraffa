# Fix: wire accepts contract-derived stubs; binds entity returns to MockData (#1500)

- **Slug**: 1500-wire-contract-derived-subject
- **File**: `lib/src/plugins/tdd/commands/wire_command.dart` (the ONLY file
  changed; gen, SubjectWriter, and the state machine untouched)

## 1. `_stubSignature` — accept what SubjectWriter emits

Before:

```dart
RegExp(r'^(int|void)\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*=>\s*'
    r'throw UnimplementedError\(', multiLine: true)
```

After:

```dart
RegExp(
  r'^([A-Za-z_][A-Za-z0-9_]*(?:<[^()<>=]*(?:<[^()<>=]*>)?[^()<>=]*>)?' // type base + optional (nested) generics
  r'[ \t]*\??)' // optional nullability marker
  r'[ \t]+([A-Za-z_][A-Za-z0-9_]*)' // the subject name
  r'\(([^)]*)\)' // the declared parameter list, verbatim
  r'[ \t]*=>[ \t]*throw UnimplementedError\(',
  multiLine: true,
)
```

Any return type (`int`, `void`, `String`, `bool`, `Object?`, `Task`,
`Task?`, `List<Task>`, `Map<String, Task>`, `List<List<Task>>`), any
parameter list (group 3, captured verbatim for the wired signature).
Still pinned to the SINGLE-LINE arrow-throw form: `[ \t]` separators (never
`\s`) stop a newline from bridging `=>` and `throw`, so the FFI harness's
wrapped seams and block-body hand implementations keep the unrecognized-
shape refusal; a leading `[A-Za-z_]` keeps commented-out stub lines from
matching.

## 2. Declared-return resolution (never degraded `Object?`)

New step 4b in `_run`, riding the SAME declared-intent machinery gen uses
(#1259, feature 071) — read-only, nothing upstream changes:

- `DeclaredRouting.declaredSignatureFor(cwd, featureName, featureDir,
  behaviorId)` → `UnitContractShape.of(...)`. A `StateError` from a
  malformed declaration refuses (errors-are-an-API, matching gen).
- Fallback: `_declaredShapeFromStubHeader(raw)` parses the SubjectWriter
  provenance header line (`//     create(String title) -> Task`) via
  `Signature.parse` when the spec artifacts are absent — the same
  declaration gen derived the stub from, never an invention. Bare-signature
  line shape required; `FormatException` lines are skipped.
- The declared return wins only when it passes `_isPlausibleTypeToken`
  (identifier + one generic nesting level + optional `?`) — defense-in-depth
  so prose-adjacent header text can never render a non-type into the wired
  file. Without a usable declared return, the legacy behavior applies
  unchanged (void stub stays void; description-derived type, else stub type).

## 3. `_defaultBodyFor` + wire body generation — bind entity returns

- `_mockBindingFor(returnType)` classifies the effective return: scalars /
  core types (`bool`, `String`, `int`, `double`, `num`, `DateTime`,
  `dynamic`, `Object`, `Never`, `void`) and `Map<...>` need no mock data;
  `E`/`E?` → `sample<E>`; `List<E>`/`Iterable<E>` → `sampleList`;
  `Set<E>` → `sampleList.toSet()` (type-correct by construction).
- Missing mock-data file (`<cwd>/lib/src/data/mock/<snake>_mock_data.dart`,
  recursive fallback mirroring `locateEntityFile`'s leniency) → honest
  misfire-stop: runner-error, exit 1, remediation names
  `zfa mock create --name <Entity>`, subject untouched.
- `_defaultBodyFor` gains an optional `mockReference`; the default branch
  emits `return <E>MockData.<accessor>;` instead of `return null as <T>;`.
- `_renderWired` renders `$effectiveReturnType $functionName($stubParams)`
  (declared parameters preserved, issue #1500 expected 5), imports the
  mock-data file when bound, and honors a description-derived explicit body
  only when its inferred type MATCHES the effective return (a declared
  `-> Task` with prose "returns 42" never renders an int body under a Task
  signature).

## 4. Backwards compatibility

- Legacy `int|void name() => throw ...` stubs take the identical legacy
  path (no declared routing → description-derived effective type) — pinned
  by U-W1/U-920/U-1500h (byte-identical render for the no-arg shape).
- The `already-wired` / `unrecognized shape` classification (#829) is
  unchanged; U-W2/U-W5/U-829a/U-829b/U-1500i/U-1500j all stay green.
