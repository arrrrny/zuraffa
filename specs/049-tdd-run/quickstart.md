# Quickstart: validating `zfa tdd run`

Runnable end-to-end validation. Prerequisites: repo checkout on branch
`049-tdd-run`, Dart SDK on PATH.

## 1. Unit suite (fast)

```bash
dart test test/plugins/tdd/services/test_list_reader_test.dart \
          test/plugins/tdd/services/run_state_store_test.dart \
          test/plugins/tdd/services/step_runner_test.dart \
          test/plugins/tdd/services/cycle_evidence_test.dart
```

Expected: all pass, no `slow` tags.

## 2. Driver + scenario suite (slow)

```bash
dart test --preset=all test/plugins/tdd/run_command_test.dart \
     test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart \
     test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart \
     test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart \
     test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart
```

Expected: all pass — scripted fake step binaries stand in for the real steps
where a step's spec is not yet merged.

## 3. Manual smoke: drive a fixture feature to DONE

```bash
cd <fixture project with specs/<f>/tdd/test-list.md (3 behaviors)>
dart run bin/zfa.dart tdd run <f>
echo "exit=$?"   # expect 0
cat specs/<f>/tdd/run-state.json   # all behaviors done
grep -c 'kind: red' specs/<f>/tdd/cycle-log.md   # one per behavior
grep -c 'kind: green' specs/<f>/tdd/cycle-log.md # one per behavior
```

Expected: progress lines per step, final summary
`run: feature=<f> result=complete ... done=3` (contract:
[contracts/run.md](contracts/run.md)).

## 4. Resume proof

```bash
# interrupt a run mid-feature (Ctrl-C), then:
dart run bin/zfa.dart tdd run <f>
```

Expected: completed behaviors are skipped (no duplicate cycle-log entries),
the run resumes at the incomplete behavior's next step, and total work is
strictly less than a fresh run (compare progress-line counts).

## 5. Honest stop

```bash
# fixture whose make step cannot satisfy B-002
dart run bin/zfa.dart tdd run <f>; echo "exit=$?"
```

Expected: non-zero, `result=stopped stopped_at=B-002:make`, `B-002` still
RED in run-state.json, B-003 untouched, resume instructions printed.
