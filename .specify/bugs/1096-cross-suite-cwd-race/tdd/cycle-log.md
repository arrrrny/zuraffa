# TDD cycle log — bug 1096

Toolchain: Dart SDK 3.13.3 (stable). All commands run at the repo root.

## RED (before the fix — `_withDirectory` without the lock)

Command: `dart test test/commands/cli_runner_cwd_race_test.dart`

Observed (both tests fail, deterministically for B1):

```text
00:00 +0 -1: ... two concurrent invocations never hold overlapping chdir windows [E]
  Expected: not '/tmp/zfa_race_b_JWEAYF'
    Actual: '/tmp/zfa_race_b_JWEAYF'
  suite B opened its chdir window while suite A was still inside its own —
  the process-wide Directory.current race of issue #1096 (writes land in the
  wrong root)

00:00 +0 -2: ... two isolates driving -C concurrently keep their writes
isolated (dart-test suite topology) [E]
  Expected: empty
    Actual: [
      'round 0: artifact for RaceIsoXRound0 missing from own workspace (CWD
       race — write landed in another root). output head: {"schema":1,
       "ok":true,"file":"lib/src/domain/services/race_iso_x_round_0_service.dart",
       ...}',
      'round 1: artifact for RaceIsoXRound1 missing from own workspace ...'
    ]
```

The cross-isolate failure is the exact production lie: the verdict reports
`ok:true` with the intended path while the write landed in another root.

First RED run additionally reproduced the second documented hazard live:

```text
PathNotFoundException: Getting current working directory failed, path = ''
  (OS Error: No such file or directory, errno = 2)
  dart:io  Directory.current
```

(a sibling deleted its temp workspace while the process CWD sat inside it).

Natural-flake repro attempt (intermittent by nature — not observed):

```text
for i in 1 2 3: dart test test/plugins/service/
  → 3 × "00:03 +25: All tests passed!"  (25/25 each)
```

Red/green discrimination was re-proven after the final test edits by
stashing the lib change and re-running: pre-fix both tests fail, post-fix
both pass.

## GREEN (fix applied)

Fix: cross-isolate PID-keyed exclusive-create lock around the whole chdir
window in `_withDirectory` (lib/src/cli/cli_runner.dart).

- `dart test test/commands/cli_runner_cwd_race_test.dart` → `00:00 +2: All
  tests passed!`
- `dart test test/plugins/service/` (the bug's repro folder) → 25/25, run
  4 × post-fix, all green:
  `00:02 +25: All tests passed!` (×3 then 1 × during commands-chunk runs)

## Refactor

None required — the fix is a contained addition to `_withDirectory` plus
static lock helpers; doc comments updated to describe the layered defense
(per-instance `_active` guard + cross-isolate lock file).
