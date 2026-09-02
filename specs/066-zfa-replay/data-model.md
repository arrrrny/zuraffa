# Data Model: `zfa replay` (spec 066)

Pure in-memory shapes the replay capability passes between stages. All live in
`lib/src/plugins/tdd/services/replay_history.dart` / `replay_runner.dart` unless
noted. No persistence: replay writes nothing but the sandbox and the optional
events file.

## ReplayGenerationStep

One recorded gen step extracted from a green entry's `generation:` block.

| Field      | Type     | Notes                                            |
|------------|----------|--------------------------------------------------|
| `command`  | `String` | The `  - step:` line, verbatim (e.g. `zfa tdd gen 066-b1 --feature 066-replay`) |
| `exitCode` | `int?`   | The `    exit:` line when parseable              |
| `purpose`  | `String?`| The `    purpose:` line                          |

## ReplayBehavior

One behavior's grouped recorded history (file order preserved).

| Field          | Type                        | Notes                                             |
|----------------|-----------------------------|---------------------------------------------------|
| `id`           | `String`                    | `- behavior:` value                               |
| `entries`      | `List<ParsedCycleEntry>`    | All sections for the id, in file order            |
| `red`          | `ParsedCycleEntry?`         | First `kind: red` entry                           |
| `green`        | `ParsedCycleEntry?`         | First `kind: green` entry                         |
| `refactors`    | `List<ParsedCycleEntry>`    | All `kind: refactor` entries                      |
| `genSteps`     | `List<ReplayGenerationStep>`| Extracted from the green section's generation block |
| `hashless`     | `bool`                      | Any parsed entry lacks a hash (schema-0 legacy)   |

Derived replayability (used for skipped-vs-replayed aggregation):
- `canReplayGen` = `green != null && genSteps.isNotEmpty`
- `canReplayVerify` = `green?.command != null`

## ReplayStage (enum)

`integrity` | `gen` | `verify`

## ReplayStepStatus (enum)

- `identical` — gen stage: `changedPaths` empty
- `green` — verify stage: actual exit equals recorded (0)
- `verified` — integrity stage: all hashed entries chain-verified (plus red
  structural checks passed)
- `drift` — gen stage: artifact paths differ
- `diverged` — any stage: integrity break / verify exit mismatch / runner error
- `skipped` — stage not replayable (with a reason string)

## ReplayStepResult

| Field      | Type                 | Notes                                             |
|------------|----------------------|---------------------------------------------------|
| `behavior` | `String`             | Behavior id                                       |
| `stage`    | `ReplayStage`        | —                                                 |
| `status`   | `ReplayStepStatus`   | —                                                 |
| `reason`   | `String?`            | Skip reason or divergence detail                  |
| `paths`    | `List<String>`       | Drift paths (gen only), project-relative, sorted  |
| `expected` | `int?`               | Recorded exit (verify divergence)                 |
| `actual`   | `int?`               | Actual exit (verify divergence/runner error)      |
| `entry`    | `String?`            | Broken entry kind (integrity divergence)          |

Derived: `bool get ok` = status ∈ {verified, identical, green, skipped}.

## ReplayDivergenceKind (constants, reported in events + lines)

- `integrity-chain-mismatch` — recomputed hash ≠ recorded hash
- `integrity-chain-linkage` — recorded prev-hash ≠ previous hashed entry's hash
- `red-missing-test-artifact` / `red-exit-zero` / `red-no-classification`
- `artifact-drift` — gen compare non-empty
- `verify-exit-mismatch` — recorded vs actual exit
- `runner-error` — command unspawnable / sandbox failure

## ReplayReport

| Field      | Type                     | Notes                                    |
|------------|--------------------------|------------------------------------------|
| `feature`  | `String`                 | —                                        |
| `behaviors`| `List<(id, steps)>`      | Per-behavior ordered step results        |
| `replayed` | `int`                    | Behaviors with ≥1 replayed (non-skipped) stage |
| `skipped`  | `int`                    | Behaviors fully skipped                  |
| `diverged` | `int`                    | Behaviors with ≥1 divergence             |
| `result`   | `String`                 | `clean` \| `divergent` \| `partial`      |
| `exit`     | `int`                    | Per spec FR-013 mapping                  |

Result rules:
- any diverged behavior → `divergent`, exit 1
- else zero replayed behaviors → `partial`, exit 2
- else → `clean`, exit 0 (skips are warnings)

## ReplayEvent (NDJSON, `--events`)

One JSON object per line, keys in stable order:

```json
{"event":"replay.start","feature":"…","behaviors":["…"],"at":"…ISO-8601…"}
{"event":"step.start","behavior":"…","step":"gen","at":"…"}
{"event":"step.end","behavior":"…","step":"gen","status":"identical"}
{"event":"step.end","behavior":"…","step":"gen","status":"drift","paths":["test/…"]}
{"event":"step.end","behavior":"…","step":"verify","status":"diverged","expected":0,"actual":1}
{"event":"step.end","behavior":"…","step":"integrity","status":"diverged","entry":"green"}
{"event":"step.end","behavior":"…","step":"gen","status":"skipped","reason":"no generation block"}
{"event":"replay.end","result":"divergent","replayed":1,"skipped":0,"diverged":1,"exit":1,"at":"…"}
```

`replay.end.exit` always equals the process exit code (spec FR-014).
