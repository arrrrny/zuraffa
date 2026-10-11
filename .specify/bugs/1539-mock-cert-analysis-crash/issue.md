# Bug Issue: mock create --certify — analysis server crash after persisted (conforms) receipt flips exit to 1

- **Slug**: 1539-mock-cert-analysis-crash
- **Fetched**: 2026-09-13T00:00:00Z
- **Issue**: 1539
- **URL**: https://github.com/arrrrny/zuraffa/issues/1539
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

### Dogfood evidence

`zfa tdd make U2` on a fresh todo host (xzx), after a ~26-minute suite baseline under cross-agent CPU load:

```
command: `... zfa.dart mock create --name Task --certify`   exit: 1
   output (tail):
   Bad state: The analysis server crashed unexpectedly
   The analysis server shut down unexpectedly.
   ✅ Success! Created/Modified:
     ✨ test/mock/task/task_mock_contract_test.dart
     ✨ test/mock/task/mock-cert.Task.json
     📝 lib/src/di/simulation/task_mock_datasource_di.dart
   ⏭ Skipped (use --force to overwrite): task_mock_data.dart, task_mock_datasource.dart
   📜 mock-certification: mock-cert:task@008d26db (conforms) → .zfa/receipts/mock-task.json
make: behavior=U2 outcome=generation-error feature=001-todo-app
```

### What's wrong

`mock create --certify` **completed its work and certified the mock** — artifacts written, `mock-cert.Task.json` recorded, receipt `mock-cert:task@008d26db (conforms)` persisted to `.zfa/receipts/` — and THEN the embedded analysis server crashed (stack through `_Timer._handleMessage`, i.e. a deferred shutdown/timeout path), flipping the exit code to 1. The caller (`make`'s generation step, spec 1001 preflight "refuses an uncertified CORE mock") sees exit 1 and stops the whole cycle with `outcome=generation-error` — even though the certification receipt on disk says **conforms**.

Net effect: a transient tooling crash (analysis server, very plausibly memory pressure under concurrent builds on the same host) poisons an already-successful certification and stops the TDD cycle on a step that actually passed.

### Suggested fix

1. **Order of operations**: treat the certification as final once the receipt is persisted — flush and close the analysis server BEFORE deciding the exit code, or ignore shutdown-phase crashes after the receipt is written.
2. **Transient classification**: an analysis-server crash (`The analysis server crashed/shut down unexpectedly`) is infra, not generation failure. Retry the analysis pass once; if the receipt exists and says `conforms`, exit 0.
3. **Consistent story on retry**: re-running `mock create --name Task --certify` currently skips the existing files (`⏭ Skipped (use --force)`) — with the receipt already present it should short-circuit to "already certified" (exit 0) instead of re-analyzing from scratch, which just re-rolls the crash dice under load.

### Context

Second false-stop of the same dogfood day (the first: #1529's blind timeout kill). Both share a theme — the cycle stops on steps whose actual work succeeded — and both were only diagnosable because the receipts/outputs survived. The engine's own evidence (`conforms` receipt) was written and then ignored by its own exit path.

## Comments

None.
