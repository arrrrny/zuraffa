# Test List: 1308-tdd-run-vacuous-guard-remedy

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1308-1 | vacuous_guard.dart exposes the shared remedy vocabulary: the exact fallback remedy string, the guard-only warning token, the marker-presence predicate, and the hand-step journal line builder | FR-005 | GREEN |
| U-1308-2 | the writer prints the loud guard-only warning (token + behavior id + remedy + test path) after writing a fallback guard-only unit test, still writes the file, and changes no emitted content | FR-002 | GREEN |
| U-1308-3 | no fallback warning fires for a scalar-declared contract (typed assertion), a prose-matched description (`returns N`), or a traced entity/void contract (marker path) | FR-002, FR-006 | GREEN |
| U-1308-4 | the run driver forwards the gen child's guard-only warning lines into the run transcript after a successful gen step | FR-003 | GREEN |
| U-1308-5 | the run driver's vacuous-green make stop on a fallback-routed behavior (marker absent) prints the exact remedy and keeps `stopped_at=<id>:make` | FR-001, SC-1 | GREEN |
| U-1308-6 | the run driver's vacuous-green make stop on a traced entity/void behavior (marker present) reports the named hand step `stopped_at=<id>:hand`, names what to write (the outcome assertion) and where (the test path), and the journal entry carries the hand-step violation | FR-004, SC-3 | GREEN |
| U-1308-REG1 | regression guard: the existing #1259 vacuous-green refusal suite passes unchanged (make semantics untouched) and the writer suite stays green | SC-4 | GREEN |

## Layer contracts

```yaml
# fr: FR-005
vacuous_guard.dart: exposes vacuousGuardFallbackRemedy, vacuousGuardWarningToken, contentCarriesVacuousGuardMarker, vacuousGuardHandStepViolation
# fr: FR-001, FR-004
run_driver_core.dart: the vacuous-green make stop arm resolves the generated test file and distinguishes the fallback path from the traced hand-delta seam by vacuousGuardMarker
```

## Key entities

```yaml
BehaviorTestWriter: writes the paired unit test; emits the guard-only fallback warning
RunDriverCore: drives the two-cycle runner; owns the vacuous-green stop messaging and the journal hand step
JournalWriter: appends the lane journal entry; carries the hand-step violation
```

## External dependencies

(none — pure-Dart messaging layer; the driver tests use the scripted fake
zfa binary from TddFixture)
