# Verification: 1344-agent-runtime-barrel-collisions

**Template Version**: `zuraffa-1.0`

## Test-first evidence (red)

Every behavioral row in `tdd/test-list.md` was written and executed BEFORE
the barrel restructure landed (T4/T5). Command (pre-fix tree, kernel cache
cleared first per protocol):

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/agent/default_barrel_collision_test.dart \
          test/agent/agent_barrel_access_test.dart \
          test/agent/default_barrel_gating_test.dart
# EXIT=1 — 4 failures
```

Red failure modes, verbatim (abridged):

- **U-1344-1** — compile-time ambiguous imports, the EXACT error class from
  issue #1344 with the same runtime source files:
  ```
  test/agent/default_barrel_collision_test.dart:24:12: Error: 'LlmClient' is
    imported from both
    'test/fixtures/agent_collision_consumer_fixture.dart' and
    'package:zuraffa/src/agent/runtime/llm_client.dart'.
  test/agent/default_barrel_collision_test.dart:26:12: Error: 'RiskTier' is
    imported from both ... and
    'package:zuraffa/src/agent/runtime/mission.dart'.
  test/agent/default_barrel_collision_test.dart:27:12: Error: 'ToolResult' is
    imported from both ... and
    'package:zuraffa/src/agent/policy/policy_hook.dart'.
  test/agent/default_barrel_collision_test.dart:37:12: Error: 'StatefulAgent'
    ... 'package:zuraffa/src/agent/runtime/stateful_agent.dart'.
  test/agent/default_barrel_collision_test.dart:38:12: Error: 'MissionTrace'
    ... 'package:zuraffa/src/agent/policy/mission_trace.dart'.
  (+ MissionBudget, ditto)
  ```
- **U-1344-2 / U-1344-3** — dedicated barrel missing pre-fix:
  ```
  test/agent/agent_barrel_access_test.dart:9:8: Error: Error when reading
    'lib/agent.dart': No such file or directory
  ```
- **U-1344-4** — `Expected: empty / Actual: [5 RegExp matches]` (the four
  `src/agent/**` export sites + one comment path reference).
- **U-1344-5** — `Expected: true / Actual: false` (`lib/zuraffa/agent.dart`
  missing).

## Green evidence (post-fix)

```
dart test test/agent/default_barrel_collision_test.dart \
          test/agent/agent_barrel_access_test.dart \
          test/agent/default_barrel_gating_test.dart
# 00:00 +7: All tests passed!
```

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1344-1 | consumer fixture + default barrel: LlmClient, RiskTier, ToolResult, StatefulAgent, MissionTrace, MissionBudget all resolve to the FIXTURE declarations | FR-003, SC-3 | GREEN |
| U-1344-2 | package:zuraffa/agent.dart exposes LlmClient, RiskTier, ToolResult, StatefulAgent, AgentKernel (runtime-owned, incl. intra-barrel AgentKernel hide arbitration) | FR-004, SC-4 | GREEN |
| U-1344-3 | dedicated barrel Type-identical to deep imports (llm_client, policy_hook, mission, stateful_agent) | FR-004, SC-4 | GREEN |
| U-1344-4 | zero `agent/` matches in lib/zuraffa.dart (SC-1 gate as a test) | FR-001, SC-1 | GREEN |
| U-1344-5 | lib/zuraffa/agent.dart carries the four former sites + verbatim hide clauses | FR-002, SC-2 | GREEN |
| U-1344-6 | regression: pre-existing barrel guard test `test/pubignore_export_guard_test.dart` still 3/3 GREEN (non-agent barrel surface unchanged) | FR-005, SC-5 | GREEN |
| U-1344-2b | both dedicated URIs (`package:zuraffa/agent.dart` facade and `package:zuraffa/zuraffa/agent.dart` real barrel) expose identical declarations | FR-004 | GREEN |

## Mutation evidence

Simulated regression mutant: re-appended
`export 'src/agent/policy/policy_shell.dart';` to the narrowed
`lib/zuraffa.dart` and re-ran the collision suite. The mutant was KILLED at
compile time — the suite immediately re-produced the ambiguity class:

```
Error: 'ToolResult' is imported from both
  'test/fixtures/agent_collision_consumer_fixture.dart' and
  'package:zuraffa/src/agent/policy/policy_hook.dart'.
Error: 'MissionTrace' is imported from both ... and
  'package:zuraffa/src/agent/policy/mission_trace.dart'.
Error: 'MissionBudget' is imported from both ... and
  'package:zuraffa/src/agent/policy/mission_budget.dart'.
```

Mutant reverted afterwards (verified: `grep -c "agent/" lib/zuraffa.dart`
→ 0). The repo-wide mutation harness (`mutation-test.xml`) scopes to the
spec-041 TDD-plugin subjects and does not cover the barrel, so this
targeted kill is the mutation evidence for this feature.

## Static analysis

- `dart analyze` on all changed files (2 barrels + facade + 4 test files):
  **No issues found!**
- `dart analyze lib bin` (whole shipped surface, worst-case consumer scope):
  0 errors, 0 warnings, 104 pre-existing `info` lints — none referencing
  `zuraffa.dart` or the agent barrels, none ambiguity/broken-import related.

## Required gates (fix protocol)

```
grep -n "agent/" lib/zuraffa.dart   → ZERO MATCHES ✓
test -f lib/zuraffa/agent.dart      → OK: agent barrel exists ✓
dart format .                       → applied; my 7 files re-verified
                                      format-clean (0 changed)
git diff --stat                     → only lib/zuraffa.dart (23+/62-)
                                      plus new files; 3 UNRELATED files the
                                      repo-wide formatter flagged (corpus
                                      regression fixtures, an old spec
                                      artifact) were RESTORED untouched —
                                      no unrelated format churn in the PR.
```

## Hard-constraint audit

- Only files changed/added: `lib/zuraffa.dart` (narrowed),
  `lib/zuraffa/agent.dart` (dedicated barrel), `lib/agent.dart` (one-line
  facade so AC3/AC4's literal `package:zuraffa/agent.dart` URI works),
  tests, and this spec feature dir. No `lib/src/agent/**` file touched
  (`git status` audit: zero modifications under `lib/src/`).
- zuraffa_agent untouched (no checkout/clone of it exists in the worktree).
- No runtime symbol renamed; all four hide clauses preserved verbatim.
