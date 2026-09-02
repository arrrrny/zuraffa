# Quickstart: `zfa replay` (spec 066)

## Replay a feature's whole recorded history

```bash
# from a project root that has specs/<feature>/tdd/cycle-log.md
zfa tdd replay 066-zfa-replay
# → per-behavior [replay] lines + final:
#   replay: feature=066-zfa-replay result=clean replayed=3 skipped=0 diverged=0
# exit 0 = the recorded loop reproduces. Silent pass, loud divergence.
```

## Replay one behavior (bisect a "it broke between Tuesday and Wednesday")

```bash
zfa tdd replay 066-zfa-replay --behavior 066-replay-clean --keep-sandbox
# exit 1 with a divergence naming the step? Inspect the sandbox:
#   [replay] 066-replay-clean gen -> drift (1 path: test/tdd/b1_test.dart modified)
#   replay: … result=divergent replayed=1 skipped=0 diverged=1 sandbox=/tmp/zfa_replay_XYZ
```

## Machine mode (agents / CI)

```bash
zfa replay specs/066-zfa-replay/tdd/cycle-log.md --events replay.ndjson
# exit code per #778: 0 clean | 1 divergent | 2 nothing replayable
# replay.ndjson: one JSON object per line, ends with {"event":"replay.end","exit":…}
```

## What gets replayed (v0)

Per behavior with recorded schema-1 evidence:

1. **integrity** — the recorded hash chain is recomputed (`CycleLog` payload) and
   red evidence is structurally validated (recorded test paths exist, exit
   non-zero, classification present).
2. **gen** — the recorded generation steps re-run in a clean sandbox copy of the
   project; the sandbox's `test/`+`lib/` trees must come out byte-identical to
   the real project's (path-stable diff).
3. **verify** — the recorded green command re-runs in the sandbox and must exit
   like recorded (green = 0).

Only-red behaviors replay their integrity stage and are skipped for gen/verify
(nothing recorded to replay yet). Narrative pre-format logs (no `- behavior:`
sections) are `partial` — replay never executes prose.
