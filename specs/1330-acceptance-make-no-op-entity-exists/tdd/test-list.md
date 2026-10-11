# Test List: 1330-acceptance-make-no-op-entity-exists

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1330-1 | the no-op pre-flight falls back on the gated entity-exists shape: the fallback lines print, `verdict: no-op` never prints, the make proceeds past the pre-flight, and the pre-seeded hand-tuned entity file is byte-identical afterwards | FR-001, FR-003, SC-1 | GREEN |
| U-1330-2 | the subject-edit-less shape keeps the bug #826 verdict verbatim: `verdict: no-op` + the enable-plugins remedy + `no subprocess was attempted` + exit 1 | FR-004, SC-4 | GREEN |
| U-1330-REG1 | regression guard: the existing #829 entity-reuse suite (U-829g/U-829h) and the run-driver #826 deferral suite pass unchanged | FR-005, SC-4 | GREEN |

## Outer loop: acceptance scenarios

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1330-1 | real-CLI make: the gated one-shot make certifies green through the tdd wire subject edit, the entity file is byte-identical, and the green evidence records the wire step (no --zfa-bin reaches the make child) | SC-2, FR-001, FR-002 | GREEN |
| A-1330-2 | real-CLI run wedge proof: two acceptance behaviors referencing the same contract row complete the run (result=complete, both done) — no make deferral, no no-op, no stopped_at | SC-3, FR-002 | GREEN |

## Layer contracts

```yaml
# fr: FR-001, FR-004
make_command.dart: _subjectEditFallbackPlan returns the reduced plan only when the first step is the bare make shape AND a tdd wire/func step remains; the pre-flight arm prints the fallback and continues instead of aborting
# fr: FR-005
run_driver_core.dart: UNCHANGED (the wedge disappears because the make never reports no-op when the fallback applied)
```

## Key entities

```yaml
MakeCommand: owns the bug-#826 pre-flight and the new subject-edit fallback arm
GenerationPlan: the effective plan; the fallback removes the no-op make step
```

## External dependencies

(none — the fast tests reuse TddFixture; the e2e tests use the real
bin/zfa.dart via a pure-exec forwarder, sc_017/sc_021 provisioning)
