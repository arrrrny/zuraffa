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
