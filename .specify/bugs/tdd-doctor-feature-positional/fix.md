# Bug Fix: tdd-doctor-feature-positional (#1585)

- **Slug**: tdd-doctor-feature-positional
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md (written by the verify step)

## Summary

The bug_828 suite's `doctor()` helper invoked `zfa tdd doctor --feature <name>`,
a flag the command has not accepted since the `b6afda42` (#840) rework moved the
feature positional. Fixing the helper (the issue's suggested fix, and the form
every other caller in the repo already uses) exposed two defects the usage error
had masked: the doctor no longer verified the cycle-log's evidence hash chain
(dropped by the same rework, still documented as the doctor's job), and the
consistent-store pin asserted the retired `doctor: feature=<f> drifts=<n>`
summary line. All three are fixed, plus one pin for the restored walk's linkage
arm, so the suite is genuinely green (14/14: the 13 pre-existing behaviors and
the new linkage pin).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` | modified | helper passes the feature positionally (+ the #1585 comment); the consistent-store pin reads the verdict envelope; new linkage pin (U1585-6) |
| `lib/src/plugins/tdd/commands/doctor_command.dart` | modified | restored the #828 evidence hash-chain walk as gate 3c + header contract entry + `_hashChainDrifts` |

## Diff Highlights

Helper (the issue's failure):

```dart
    return runner.runCapturing([
      'tdd',
      'doctor',
      // Issue #1585: doctor takes the feature POSITIONALLY — it declares
      // only --json/--repair/--project, so a --feature flag is a usage error.
      feature,
      '--project',
      fx.root.path,
    ]);
```

Restored walk (ported from `1183009e` `_verifyChain`; same drift wording, same
`genesisHash` start, same `CycleLog.payloadFromFields` canonical payload the
writer hashes and `replay_history.verifyIntegrity` recomputes):

```dart
    final chainDrifts = _hashChainDrifts(await evidence.entries());
    if (chainDrifts.isNotEmpty) {
      drifts.addAll(chainDrifts);
      final fix =
          'restore the cycle-log from a trusted source, then re-run '
          '`zfa tdd run $feature` to re-certify';
      ...
      _printVerdict(
        feature: feature,
        verdict: 'drift',
        prescription: 'resume',
        fix: fix,
        drifts: drifts,
      );
      exitCode = 1;
      return;
    }
```

## Tests Added or Updated

- **One new test (U1585-6)**: `bug 828 RED: doctor detects a broken prev-hash
  LINKAGE (the reordered/edited trail) and prescribes a fix`. Added during the
  verification audit — mutant sampling showed the restored walk's linkage arm
  had no pin (a content-only walk survived), so the pin isolates it: the trail's
  `- prev-hash:` is severed from genesis, which only the linkage arm can see.
- Two assertions updated in place, keeping their original intent: the helper's
  invocation form (#1585) and the consistent-store pin's zero-drift carrier
  (`drifts=0` summary line → the verdict envelope's empty `drifts`).
- U1585-3 is the pre-existing tampered-chain case — the RED pin that surfaced
  the dropped walk; it kills the "content arm removed" mutant, U1585-6 kills the
  linkage mutant (see `tdd/verification.md`).

## Local Verification

- `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
  → pre-fix `+9 -4` (usage error, the issue); helper-only `+11 -2` (the two
  deeper defects); final `+14: All tests passed!`
- Mutation sampling: M1 (walk disabled) killed by both hash pins; M2 (linkage arm
  dropped) killed by the new linkage pin — both mutants reverted, tree re-run green.
- `dart analyze lib/src/plugins/tdd/commands/doctor_command.dart test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` → `No issues found!`
- `dart format` on both files → `0 changed`
- Sibling doctor suites swept for regressions — see `tdd/verification.md`.

## Deviations from Assessment

The assessment (from the issue) scoped the fix to the helper and expected
`13/13` from that alone. The helper fix is necessary and landed as suggested,
but it converts the 4 usage-error failures into 2 real disagreements, so the
issue's Expected required two more fixes:

1. **The evidence hash-chain walk was missing.** The doctor at `1183009e`
   (the commit that introduced this suite) verified every schema-1 entry's
   chain; the `b6afda42` rework dropped it. Current source still documents the
   behavior: `cycle_log.dart:70-71` — "The doctor recomputes this from the
   parsed entry and reports any mismatch as drift with a fix line" — and
   `payloadFromFields` is documented as "the doctor's view of a rendered
   entry". Observable consequence before the fix: `zfa tdd doctor` reported
   `stores agree — no drift detected` for a cycle-log whose certified `exit`
   fact had been edited. Restored by porting the pre-rework implementation
   (same drift text, same fix line, same `resume` prescription).
2. **The `drifts=<n>` summary line is gone.** The consistent-store pin asserted
   `contains('drifts=0')`; the verdict envelope (bug #840 / issue #969) replaced
   that line, and zero drifts is now the empty `drifts` array on the final JSON
   line — the idiom every sibling doctor suite reads. The assertion was updated
   to the envelope contract; the test's intent (consistent stores → no drift) is
   unchanged and the exit-0 assertion is untouched.

Both are recorded as FR-003 / FR-004 in `spec.md`. The user was consulted on the
scope before either was written (chose "complete to 13/13").

## Follow-ups

- The suite is slow-tagged: only `--preset=all` runs it, which is how this drift
  survived 4 months of green CI. Any sibling that pins a command's invocation
  form should be exercised in a lane CI actually runs (cf. the #1573
  execute-the-prescription test).
- The `--repair` GC path and the other doctor gates were not touched.
