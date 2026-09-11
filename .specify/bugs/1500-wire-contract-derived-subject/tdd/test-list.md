# Test List: 1500-wire-contract-derived-subject

feature: 1500-wire-contract-derived-subject
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U-1500a | wire accepts the contract-derived stub (declared entity return) and wires the declared type + TaskMockData.sampleTask with both imports | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500b | missing mock-data file misfire-stops naming `zfa mock create --name Task`; subject untouched | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500c | declared List<Task> return binds to sampleList | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500d | declared Task? return binds to sampleTask | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500e | declared String return keeps a type-correct literal, no mock data | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500f | declared bool return keeps `return false;`, no mock data | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500g | declared int return keeps `return 0;`, no mock data | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500h | legacy no-arg int/void stubs wire byte-compatibly | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500i | a commented-out stub line is not a stub (already-wired) | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500j | a hand-written non-stub UnimplementedError shape is still refused | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500k | the stub provenance header resolves the declared return when spec artifacts are absent | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500l | the declared return wins over description inference | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500m | a declared return entity different from --entity is imported and bound to its OWN mock data when present; the wired subject passes `dart analyze` | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500n | a declared entity whose mock data the plan never creates falls back to the stub's renderable shape — no dead-end, no crashing cast | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500o | declared Set<Task> return binds to sampleList.toSet() | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500p | declared Iterable<Task> return binds to sampleList | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500q | declared nullable collection (List<Task>?) binds (no crashing null cast) | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500r | a prose-adjacent stub-header return is rejected by the plausibility gate (description-derived type wins) | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500s | declared `num`/`DateTime` returns get type-correct literals, never `return null as <T>;` | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500t | a malformed declared signature is refused (errors are an API, never a silent prose fallback) | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-1500u | a declared return entity that is not a generated entity falls back to the stub's renderable shape (never an undefined class) | FR-1500 | unit | DONE | test/plugins/tdd/bug_1500_wire_contract_subject_test.dart |
| U-W3 | a missing subject file is a hard runner-error naming the gen remediation (macOS symlinked-temp-root path canonicalization) | FR-1500 | unit | DONE | test/plugins/tdd/wire_command_test.dart |
