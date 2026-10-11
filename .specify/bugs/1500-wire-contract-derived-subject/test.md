# Test: contract-derived subject wiring (#1500)

- **Slug**: 1500-wire-contract-derived-subject
- **Suite**: `test/plugins/tdd/bug_1500_wire_contract_subject_test.dart`
  (fast tier, in-process `CliRunner` against a `TddFixture` — the same
  conventions as `wire_command_test.dart`)

## Behavior list (TDD step 2 artifacts)

| ID | Behavior | Kind | State |
| --- | --- | --- | --- |
| U-1500a | a contract-derived stub with a declared entity return wires to the declared type + `TaskMockData.sampleTask`, declared parameters preserved, both imports present, no cast-null body | unit | DONE |
| U-1500b | a missing mock-data file is an honest misfire-stop naming `zfa mock create --name Task`; the subject is untouched | unit | DONE |
| U-1500c | a declared `List<Task>` return binds to `sampleList` | unit | DONE |
| U-1500d | a declared `Task?` return binds to `sampleTask` | unit | DONE |
| U-1500e | a declared `String` return keeps a type-correct literal; no mock data needed | unit | DONE |
| U-1500f | a declared `bool` return keeps `return false;`; no mock data needed | unit | DONE |
| U-1500g | a declared `int` return keeps `return 0;`; no mock data needed | unit | DONE |
| U-1500h | legacy no-arg int/void stubs keep wiring byte-compatibly (backwards compatible) | unit | DONE |
| U-1500i | a commented-out stub line is not a stub — already-wired survives the widened shape | unit | DONE |
| U-1500j | a hand-written non-stub UnimplementedError shape is still refused (the widened regex stays safe) | unit | DONE |
| U-1500k | the stub provenance header resolves the declared return when the spec artifacts are absent (header fallback) | unit | DONE |
| U-1500l | the declared return wins over description inference | unit | DONE |

Plus the pre-existing wire pins (unchanged file, all green post-fix):
U-W1–U-W7, U-829a, U-829b, U-920–U-920e in
`test/plugins/tdd/wire_command_test.dart`.

## Coverage against the issue's must-handle matrix

| Required shape | Covered by |
| --- | --- |
| scalar returns (String, int, bool) | U-1500e, U-1500f, U-1500g, U-1500h |
| entity returns (Task) | U-1500a, U-1500b |
| generic returns (List<Task>) | U-1500c |
| nullable returns (Task?) | U-1500d |
| legacy no-arg stubs (backwards compat) | U-1500h + all U-W/U-920 pins |
| safety of the widened regex | U-1500i, U-1500j, U-W5, U-829b |
| declared beats inferred | U-1500l, U-1500k |
| honest misfire-stop | U-1500b |
