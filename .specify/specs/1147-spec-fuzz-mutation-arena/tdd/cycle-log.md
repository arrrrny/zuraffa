# TDD cycle log — 1147-spec-fuzz-mutation-arena

All runs below were executed in this session, on branch
`feat/1147-spec-fuzz-mutation-arena`, Dart SDK 3.13.4 (stable), linux_x64.

## Cycle 1 — the CLI run-semantics seam (RED → GREEN)

### R1 — red (the new seam does not exist)

```
$ dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart
00:00 +0 -1: loading test/commands/spec_fuzz_command_1147_run_semantics_test.dart [E]
  Failed to load "test/commands/spec_fuzz_command_1147_run_semantics_test.dart":
  test/commands/spec_fuzz_command_1147_run_semantics_test.dart:408:13: Error:
  No named parameter with the name 'runPreflight'.
              runPreflight: preflight ?? _greenPreflight,
              ^^^^^^^^^^^^
  lib/src/commands/spec_command.dart:16:3: Context: Found this candidate, but the arguments don't match.
    SpecCommand() {
    ^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

### G1 — green (seam threaded; command body, flags, gates, exits untouched)

```
$ dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart
00:00 +0: run semantics (issue #1147: exit codes) weak spec: mutants survive, exit 1, certified=false
00:00 +1: run semantics (issue #1147: exit codes) strong spec: every mutant killed, exit 0, certified=true
00:00 +2: report shape (issue #1147: machine-readable weakness report) rows carry the documented fields {mutation_id, spec_line, operator, verdict, evidence}
00:00 +3: report shape (issue #1147: machine-readable weakness report) the five declared operators all appear against the all-element fixture
00:00 +4: operator filter (issue #1147: --operators) --operators weaken,drop judges only the selected operators
00:00 +5: budget (issue #1147: --budget N) --budget 2 caps the judged mutants and is recorded
00:00 +6: replay (issue #1147: deterministic, replayable) same seed + budget -> byte-identical report
00:00 +7: honest refusals (issue #1147: never grade a red loop) a red preflight is refused, never graded (usage exit)
00:00 +8: All tests passed!
```

### G2 — siblings green (no existing test modified)

```
$ dart test test/commands/spec_fuzz_command_test.dart \
    test/plugins/tdd/services/spec_fuzz_auditor_test.dart \
    test/plugins/tdd/services/spec_mutator_test.dart
00:01 +50: All tests passed!
```

### G3 — post-format lane re-run

```
$ dart format . && dart format --set-exit-if-changed <changed files>
Formatted 2944 files (1 changed) in 7.21 seconds.   # only the new test file
Formatted 3 files (0 changed) in 0.03 seconds.      # FMT_EXIT=0 — idempotent
$ dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart \
    test/commands/spec_fuzz_command_test.dart \
    test/plugins/tdd/services/spec_fuzz_auditor_test.dart \
    test/plugins/tdd/services/spec_mutator_test.dart
00:11 +58: All tests passed!
```

## Cycle 2 — real-process verification (the seeded-weakness demo lanes)

Real CLI (`dart run bin/zfa.dart`), real `dart test` subprocesses per
mutant, real spec mutation/restore — run via the session probe scripts
(`scripts/probe_demo_fixture.sh`, `scripts/probe_strong_fixture.sh`).

### Weak round (proven spec weaknesses, real spawns)

```
gate: notAssessed   mutations: 6   killed: 0   survived: 3   not_assessed: 3
certified: false   fuzz_was_run: true   restoration_verified: true
SM-001 weaken      survived — no pin fired ... no committed assertion pins the original value(s) Hello
SM-002 swap-literal survived — no pin fired ... 'Hello'
SM-003 drop        survived — no pin fired ... '2'
SM-004 drop-must-not notAssessed — behavior U2 is not derived from the mutated spec (ids shifted) — cannot re-derive its test
SM-005 swap-literal  notAssessed — behavior U3 is not derived from the mutated spec (ids shifted) — cannot re-derive its test
SM-006 widen         notAssessed — behavior U3 is not derived from the mutated spec (ids shifted) — cannot re-derive its test
```

The survivors carry the weakness evidence (the pins checked and silent);
the not_assessed rows are the documented derivation limit of the 0967
demo fixture shape (no `traces:` lines, AC renumbering after a drop —
the spec's own Edge Cases entry: judged on pins only, never a kill,
never a pass). The round refuses honestly (usage-class gate) instead of
grading a partially-assessed round as pass or fail.

### Strong round (intent pinned, real spawns)

```
gate: pass   mutations: 13   killed: 13   survived: 0   not_assessed: 0
certified: true   fuzz_was_run: true   restoration_verified: true   EXIT=0
SM-001 weaken        killed — P3:assertion original value "42" asserted at test/tdd/arena-greeter/a1_test.dart:1
SM-002 swap-literal  killed — P2:loop-red regenerated test failed (exit 1): Expected: <43>
SM-003 weaken        killed — P3:assertion "0" asserted at a2_test.dart:1
SM-005 drop          killed — P3:assertion "0" asserted at u2_test.dart:1
SM-009 drop-must-not killed — P3:assertion "42" asserted at a1_test.dart:1
SM-013 widen         killed — P3:assertion "0" asserted at a2_test.dart:1
   (SM-004/006/007/008/010/011/012 likewise killed — full table in the report)
```

### Replay determinism (same seed/budget → identical bytes)

```
REPLAY_EXIT=0
REPLAY: byte-identical   (cmp of spec-fuzz.json across two real rounds)
```

## Flagged pre-existing failure (NOT this branch's regression)

`test/plugins/tdd/spec_fuzz_demo_test.dart` (slow tier, `--preset=all`)
fails on THIS branch and IDENTICALLY on a pristine `master` worktree
(`git worktree` at a9329746, `dart pub get`, same command):

```
the weak spec survives the green loop and spec fuzz flags it; ... [E]
  Expected: <1>
    Actual: <2>
corpus mode walks a cataloged corpus and gates on the weak feature [E]
  Expected: <1>
    Actual: <0>
```

The failure is deterministic in the demo fixture's derivation shape
(the `ids shifted` not_assessed rows above make the weak round exit 2),
not load flakiness, and predates this branch. The 0967 demo's contract
(`not_assessed=0` on the traces-less fixture) does not hold on master
today. Flagged for the maintainer; out of 1147's scope (one PR per spec;
the constraint "do NOT change existing tdd run semantics" forbids
re-deriving the 0967 fixture machinery here).
