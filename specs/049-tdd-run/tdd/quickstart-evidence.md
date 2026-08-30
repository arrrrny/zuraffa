# Quickstart Evidence: `zfa tdd run`

Recorded 2026-08-30 from a REAL run of quickstart.md scenarios 1–5
(task T024) on branch `049-tdd-run` @ `9986bfec`, Dart 3.13.1 (the
CI-pinned SDK), Linux x64. Scenarios 3–5 drive the real CLI entrypoint
(`dart run bin/zfa.dart tdd run …`) against a scratch fixture with a
scripted fake zfa step binary — specs 047 (`make`) and 048 (`refactor`)
are unmerged, and the driver consumes their contracts, not their code.

## 1. Unit suite (fast)

```
$ dart test test/plugins/tdd/services/test_list_reader_test.dart \
          test/plugins/tdd/services/run_state_store_test.dart \
          test/plugins/tdd/services/step_runner_test.dart \
          test/plugins/tdd/services/cycle_evidence_test.dart
00:01 +28: All tests passed!
```

## 2. Driver + scenario suite (slow)

Note: the repo's `dart_test.yaml` excludes the `slow` tag by default, so
the `--tags slow` form selects nothing; the working form (recorded in
quickstart.md) is `--preset=all`.

```
$ dart test --preset=all test/plugins/tdd/run_command_test.dart \
     test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart \
     test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart \
     test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart \
     test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart
00:04 +26: All tests passed!
```

## 3. Manual smoke: drive a fixture feature to DONE

```
$ dart run bin/zfa.dart tdd run 090-smoke --project <fixture> --zfa-bin <fake>
zfa tdd run: feature 090-smoke — 3 behavior(s)
[run] B-001 gen -> ok
[run] B-001 verify-red -> certified
[run] B-001 make -> green
[run] B-001 refactor -> clean
[run] B-002 gen -> ok
[run] B-002 verify-red -> certified
[run] B-002 make -> green
[run] B-002 refactor -> clean
[run] B-003 gen -> ok
[run] B-003 verify-red -> certified
[run] B-003 make -> green
[run] B-003 refactor -> clean
run: feature=090-smoke result=complete pending=0 red=0 green=0 done=3
$ echo $?
0
```

`run-state.json`: all three behaviors `done`. Cycle log grep counts:
`kind: red` → 3, `kind: green` → 3 (one per behavior). Step invocations:
12 (four per behavior, in list order).

## 4. Resume proof

A run was killed (`kill -9`, the scripted Ctrl-C) while `gen B-002` was
in flight. The persisted state:

```json
{
  "feature": "090-smoke",
  "behavior_states": {
    "B-001": "done",
    "B-002": "pending",
    "B-003": "pending"
  },
  "in_flight_behavior_id": "B-002",
  "in_flight_step": "gen",
  "in_flight_owner_pid": 13868,
  "dropped": []
}
```

The re-run skipped DONE `B-001` entirely, re-executed the in-flight
`gen` step for `B-002`, and drove the remainder:

```
zfa tdd run: feature 090-smoke — 3 behavior(s)
   1 already done — skipping
[run] B-002 gen -> ok
[run] B-002 verify-red -> certified
[run] B-002 make -> green
[run] B-002 refactor -> clean
[run] B-003 gen -> ok
[run] B-003 verify-red -> certified
[run] B-003 make -> green
[run] B-003 refactor -> clean
run: feature=090-smoke result=complete pending=0 red=0 green=0 done=3
$ echo $?
0
```

Invocations in the resumed run: **8** vs **12** for the fresh run —
strictly less work, as FR-005 requires.

## 5. Honest stop

A fixture whose `make` step cannot satisfy `B-002`
(`outcome=unexpressible`, exit 1):

```
$ dart run bin/zfa.dart tdd run 090-smoke --project <fixture> --zfa-bin <fake>
zfa tdd run: feature 090-smoke — 3 behavior(s)
[run] B-001 gen -> ok
[run] B-001 verify-red -> certified
[run] B-001 make -> green
[run] B-001 refactor -> clean
[run] B-002 gen -> ok
[run] B-002 verify-red -> certified
[run] B-002 make -> unexpressible
zfa tdd run: step failed — behavior=B-002 step=make outcome=unexpressible
   make: behavior=B-002 outcome=unexpressible feature=090-smoke
   resume: fix the failing step, then re-run `zfa tdd run 090-smoke`
run: feature=090-smoke result=stopped pending=1 red=1 green=0 done=1 stopped_at=B-002:make
$ echo $?
1
```

Residual state: `B-001` done, `B-002` red (its last completed state),
`B-003` pending. `B-003` invocations after the stop: **0**. The exit code
and the stopping behavior/step appear in the machine summary, and the
resume instructions name the command.

## Verdict

All five quickstart scenarios behave exactly as specified (SC-001
end-to-end drive, SC-002 resumability with strictly less work, SC-003
honest stop with no later behavior started).
