# Tasks: SPEC 1565 — func recognizes the contract-derived subject; make plan skips the doomed step

**Feature ID:** 1565-func-recognize-contract-derived-subject
MVP first: the shared predicate service + func no-op unblock the dead-end;
the plan skip removes the doomed spawn. Every task is non-behavioural to the
gen / wire / contract lanes.

## TDD (red → green)

- [x] T1 — Write `test/plugins/tdd/services/subject_provenance_1565_test.dart`:
      marker detection (both markers / missing either), func rewritability
      (legacy bounded shapes true, entity-typed contract-derived false),
      declaration recognition (entity, nullable, generic, parametrized),
      refusal classification. RED first (service does not exist).
- [x] T2 — Write `test/plugins/tdd/commands/func_command_1565_test.dart`:
      U-1565-1/2/6 no-op success paths (exit 0, `contract-derived-noop`,
      byte-identical subject), U-1565-3/4 preserved refusals, U-1565-5
      already-implemented untouched. RED first.
- [x] T3 — Write `test/plugins/tdd/services/generation_planner_1565_test.dart`:
      func step dropped when `skipFuncScaffold`, kept when absent/false,
      plan invariants hold (expressible, ends in build). RED first.
- [x] T4 — Write `test/plugins/tdd/make_command_1565_test.dart`: the make
      records NO `tdd func` generation command for a contract-derived
      subject and the subject is byte-identical after the make. RED first.

## Implementation (non-behavioural to gen/wire/contract lanes)

- [x] T5 — `lib/src/plugins/tdd/services/subject_provenance.dart`: the
      provenance markers (verbatim from SubjectWriter's contract-derived
      template), `funcRewritableStubPattern` (moved from
      `func_command._stubSignature`), `contractDerivedDeclarationPattern`,
      `isContractDerivedGenStub`, `funcWouldRefuseContractDerivedStub`.
- [x] T6 — `func_command.dart`: reference the moved pattern; in the refusal
      branch, recognize the provenance-backed contract-derived shape and
      report `FuncOutcome.contractDerivedNoop` (exit 0, verdict stopped);
      everything else byte-identical.
- [x] T7 — `generation_planner.dart`: `BehaviorSummary.skipFuncScaffold`
      (default false, `fromRecord` param) + `_functionSurfacePlan` omits
      the func step when set.
- [x] T8 — `make_command.dart`: read the subject before planning, compute
      `skipFuncScaffold`, pass it through, print the skip note.

## Verification

- [x] T9 — `dart analyze` on every changed file: zero new warnings.
- [x] T10 — New suites green; func command suite, planner suite, and the
      #1517/#1259 regression suites green.
- [x] T11 — `dart format` clean on the touched files; record
      `tdd/verification.md` with the red evidence and green receipts.
