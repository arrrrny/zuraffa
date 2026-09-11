# Fix: BUG 1511 — unexpressible message drift (bug 657 assertion)

- **Slug**: 1511-unexpressible-message-drift
- **Date**: 2026-09-12
- **Branch**: `fix/1511-unexpressible-message-drift`
- **Baseline**: `master` @ `03cdf45b`

## What changed

Exactly one file, test-only:

```
test/plugins/tdd/make_command_test.dart | 27 +++++++++++++++++----------
1 file changed, 17 insertions(+), 10 deletions(-)
```

No production file (`lib/`, `bin/`, `tool/`) was touched. The make command logic, the
planner, and the state machine are byte-identical to baseline.

## The fix

In the `US4 — misfire-stop on unexpressible behaviors` group, the
"bug 657" unexpressible-path test was updated from the stale message contract to the
current one:

| Before (stale) | After (current contract) |
| --- | --- |
| test name: "names the verb and the stub path with the manual-implementation hint" | test name: "phrases the refusal in behavior terms — it names the behavior, quotes the full description, and cites the STOP-ON-ROADBLOCK policy" |
| `contains("no generator for 'provision'")` | `contains('no generator surface maps the behavior')` |
| `contains('implement manually at')` | `contains('description "provision bespoke DSL syntax with no generator surface"')` |
| `contains(fx.subjectPathOf('B-042'))` (stub path) | `contains('STOP-ON-ROADBLOCK policy')` |
| `contains('then re-run')` | (removed — no longer part of the message) |
| outcome line `make: behavior=B-042 outcome=unexpressible feature=…` | unchanged (still asserted) |
| `exitCode isNot(0)` | unchanged (still asserted) |

The test name keeps the `bug 657:` prefix so `-n "bug 657"` continues to match both
bug-657 tests (unexpressible refusal + render-type green path).

## Why the test is pinned this way

The refusal is produced by `GenerationPlanner._unexpressibleReason()`
(`lib/src/plugins/tdd/services/generation_planner.dart`) and printed by the
unexpressible stop in `lib/src/plugins/tdd/commands/make_command.dart`:

```
zfa tdd make: cannot plan a generation for behavior "B-042". behavior "B-042" requires
an implementation the zuraffa generation pipeline cannot express: no generator surface
maps the behavior description "provision bespoke DSL syntax with no generator surface"
to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per
the STOP-ON-ROADBLOCK policy.
make: behavior=B-042 outcome=unexpressible feature=090-tdd-fixture
```

The new assertions pin the load-bearing parts of that contract (behavior-phrased
refusal, exact quoted description, policy reference) without over-pinning the
incidental prefix, and keep the honest non-zero misfire contract.

## Constraints verification

- Only the test file changed (`git diff --stat` above; `git status --porcelain` shows
  only `M test/plugins/tdd/make_command_test.dart`).
- `dart analyze test/plugins/tdd/make_command_test.dart` → `No issues found!`
- `dart format --output=none --set-exit-if-changed` on the changed file → 0 changed.
- Red → green evidence recorded in `red-evidence.md` / `tdd/verification.md`.
