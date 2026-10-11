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

## 5. Review round — pull/1516 findings (same file)

| Finding | Resolution |
| ------- | ---------- |
| 🟠 The mock binding keyed off the DECLARED return entity, but the plan's `mock create` runs for the TRACED (`--entity`) entity — a permanent dead-end | The hard-stop now applies only when `mockBinding.entity == entityName` (the entity the plan creates). On a mismatch the declared entity's OWN mock data is bound when it exists; otherwise wire degrades to the stub's renderable shape instead of naming a step the plan never runs. |
| 🟠 The declared return's class was never imported → the wired subject did not compile | When the declared base differs from `--entity`, its entity file is resolved with `locateEntityFile` and imported (`package:`); if the class is not a generated entity, the return degrades to the stub's shape (never an undefined class). |
| 🟡 `num`/`DateTime` were refused a mock but had no literal → `return null as <T>;` | `_defaultBodyFor` gains `case 'num': return 0;` and `case 'DateTime': return DateTime.now();`. |
| 🟡 The new refusal/fallback branches were untested | U-1500m/n/u/o/p/q/r/s/t pin the mismatch resolution, `Set`/`Iterable`/nullable-collection accessors, the plausibility-gate rejection, the `num`/`DateTime` literals, and the malformed-declaration refusal. |
| 🟡 The fixture hand-copied `SubjectWriter`; nothing compiled the output | `contractStub` now renders through `SubjectWriter(contractShape: UnitContractShape.of(Signature.parse(...)))`; U-1500m/n/u run `dart analyze` over the wired subject and expect exit 0. |
| 🔵 `deriveSubjectSignature` computed twice per run | Hoisted — the `DerivedSignature` is computed once and passed to `_renderWired`. |
| 🔵 Nullable collections were not bound (`List<Task>?` → `return null as List<Task>?;`) | `_mockBindingFor` strips the nullability marker before the collection unwrap, so `List<Task>?` binds to `sampleList`. |
| 🔵 No staleness note on the stub-header fallback | Documented in `_declaredShapeFromStubHeader`'s doc comment (the header outranks the spec only when the spec artifacts are absent). |
| 🔵 `case 'String'` in `_defaultBodyFor` is unreachable | Kept deliberately: `_defaultBodyFor` stays self-contained for its own callers rather than depending on `_renderWired`'s earlier `String` branch. |
| ⚠️ The stated `+27` evidence did not reproduce on macOS (`+26 -1`, U-W3) | Fixed: the missing-subject case canonicalizes through its nearest existing ancestor (`_canonicalizeMissingPath`), so a symlinked temp root no longer misreads the project's own path as outside the root. U-W3 is green on macOS now. |
