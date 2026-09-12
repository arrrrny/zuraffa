# Issue: wire cannot wire contract-derived subjects

- **Issue**: https://github.com/arrrrny/zuraffa/issues/1500
- **Slug**: 1500-wire-contract-derived-subject
- **Component**: `zfa tdd wire` (`lib/src/plugins/tdd/commands/wire_command.dart`)
- **Related**: #1498 (no entityName derived from declared return), #1259 (contract-derived subjects), #1308 (hand-delta seam)

## Report

`zfa tdd wire <id>` can only wire a subject whose stub matches the legacy
no-arg function stub:

```dart
^(int|void)\s+([A-Za-z_][A-Za-z0-9_]*)\(\)\s*=>\s*throw UnimplementedError\(
```

Every contract-derived subject has a different shape — declared parameters
plus a degraded `Object?` return:

```dart
Object? subject_u2(String title) => throw UnimplementedError('...');
```

So wire falls into `stub == null` and refuses. The entity create → mock
create → wire → build pipeline can never complete for a contract-derived
behavior.

## Reproduction

```markdown
## Layer Contracts
**Domain**:
- `TaskStore`: `create(String title) -> Task`, `readAll() -> List<Task>`
```

```bash
zfa tdd plan 001-todo-app
zfa entity create -n Task --field id:String --field title:String
zfa tdd gen U2
zfa tdd wire U2 --entity Task --feature 001-todo-app
# -> runner-error, "unrecognized shape", exit 1
```

## Second half: wire has nothing real to return

Even with the regex fixed, `_defaultBodyFor` emits `return null as Task;` —
a runtime cast error routed to runner-error. The pipeline already generated
the value one step earlier: `zfa mock create --name Task` writes
`TaskMockData.sampleTask`. wire never looks for it.

## Root cause

wire predates contract-derived subjects (#1259) and declared-signature
routing (feature 071). It assumes the only stub gen writes is
`int foo() => throw UnimplementedError(...)` and the only wired dummy is a
type-correct literal. Both assumptions are false for every entity-returning
contract.

## Expected

1. `_stubSignature` accepts what SubjectWriter emits: any return type, any
   parameter list.
2. wire resolves the declared signature and uses the declared return —
   never degraded `Object?`.
3. For entity returns, wire binds to `<Entity>MockData.sample<Entity>` /
   `.sampleList` and imports it.
4. Missing mock-data file → honest misfire-stop naming
   `zfa mock create --name <Entity>`.
5. Wired signature keeps declared parameters.

## Hard constraints

- Fix ONLY `wire_command.dart` (`_stubSignature`, `_defaultBodyFor`, wire
  body generation). Do NOT change gen, SubjectWriter, or the state machine.
- Must handle: scalar returns (String, int, bool), entity returns (Task),
  generic returns (List<Task>), nullable returns (Task?).
- Must not break legacy no-arg stubs (backwards compatible).
- Must pass `dart analyze` with no new warnings.
