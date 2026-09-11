# Test List: 1407-make-gate-errors-only

Derived from spec.md + plan.md (speckit.tdd.plan fallback — the repo has no
`.zfa.json`, so the LLM-guided derivation applies). Every behavior gets a
failing test BEFORE its implementation lands (red-green-refactor).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1407-1 | a skin-lane widget behavior whose make plan's terminal build step is refused by the analyze gate on 0 error(s) + 1 warning and whose target test passes after the view step completes outcome=green, exit 0, with the `warnings are non-blocking` verdict line and the warning line logged and the green evidence appended — never `green-with-failed-build` nor `generation-error` | FR-001, FR-002, FR-004 | GREEN |
| A-1407-2 | an engine-lane unit behavior under the identical warnings-only refusal and a green-after-scaffold target test completes outcome=green, exit 0, with the same verdict-line text as the skin lane (behavior id and plan steps aside) — one shared gate object, no cross-lane strictness drift | FR-001, FR-004 | GREEN |
| A-1407-3 | an already-green sibling in the same feature takes the #694 skip transition: outcome=skipped, exit 0 — the gate's effective warning strictness matches the normal transition's (non-blocking in both), no inconsistent strictness within the same run | FR-004 | GREEN |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1407-1 | a warnings-only gate refusal whose behavior's target test still fails after generation stops with outcome=generation-error, exit 1, no green entry, and the subject restored (the #1036 failed-make contract) — the red test decides, never the warning | FR-003, FR-006 | GREEN |
| U-1407-2 | a build verdict carrying 1 analyzer error keeps the #942 refusal byte-identical: outcome=generation-error, the `analyzer error(s)` note, no green entry | FR-003 | GREEN |
| U-1407-3 | a profile whose machine-readable Keys block carries `analyze-gate: warnings-blocking` restores the pre-#1407 grading: the warnings-only refusal reaches the #737/#942 tolerance and a passing target test yields outcome=green-with-failed-build, exit 0 | FR-005 | GREEN |
| U-1407-4 | the default gate (no `analyze-gate` key in the profile) is errors-only: a warnings-only refusal with a green target test completes outcome=green, exit 0 | FR-005 | GREEN |
| U-1407-5 | an explicit `analyze-gate: errors-only` key and an unrecognized value (`analyze-gate: strict-everything`) behave identically to the absent-key default (outcome=green under the same refusal with a green target test) — the opt-in is exactly the `warnings-blocking` value, nothing else; a missing profile misfire-stops runner-error before any gate runs (the pre-existing profile contract, vacuously default) | FR-005 | GREEN |
| U-1407-6 | gate attribution edges: a build failure WITHOUT the gate's refusal message keeps the #737 tolerance path; a refusal message claiming 0 errors whose raw output carries analyzer `error -` lines keeps the honest stop (the shared parser wins); a voluminous multi-warning verdict logs a capped sample with a remainder count | FR-002, FR-006 | GREEN |

## Layer contracts

```yaml
# fr: FR-001, FR-002, FR-003, FR-006
make_command.dart: errors-only analyze-gate re-grade in the !pipelineResult.completed block (terminal-build-step precondition, gate-message attribution, shared-parser cross-check, non-blocking fall-through)
# fr: FR-002
make_command.dart: _logWarningsOnlyGateRefusal — verdict line (counts + issue #1407 policy) + capped `warning -` lines
# fr: FR-005
make_command.dart: _profileWarningsBlocking — optional `analyze-gate:` Keys-block reader (warnings-blocking opt-in; everything else defaults errors-only)
```

## Key entities

```yaml
MakeOutcome: unchanged — the non-blocking path ends in the existing green token; no new outcome kind
BuildCommand.countAnalyzerIssues: consumed unchanged (the single #1035 line-format contract); the dart analyze invocation and the build command are read-only for this feature
TddProfile file (.specify/memory/tdd-profile.md): gains an OPTIONAL machine-readable `analyze-gate:` key; absent key = errors-only default
```

## Suite entry points

- `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` (new — all
  behaviors; TddFixture temp project + fake zfa bin, real `dart test`
  children, per the make_command_test.dart conventions)
- `test/plugins/tdd/make_command_test.dart` (#737/#942 tolerance group —
  the regression family that must stay green)
- `test/commands/build_command_unit_test.dart` (the shared parser pins)
