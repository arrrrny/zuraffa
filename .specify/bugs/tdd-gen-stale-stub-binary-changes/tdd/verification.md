# TDD Verification — tdd-gen-stale-stub-binary-changes (#683)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/683
- **Branch**: fix/683-tdd-gen-stale-stub-binary-changes
- **Date**: 2026-09-01
- **Verdict**: PASS — the reused/reused staleness gap is reproduced by a failing test on pre-fix code and is killed by the fix; the full gen-adjacent surface is green.

## Counts

| Fact | Value |
|------|-------|
| Behaviors covered | 3 new tests (regeneration, silent skip, progressed-subject guard) |
| Red-phase proven | Yes — 1 test failed on pre-fix code with the exact symptom |
| Test-after confirmed | Yes — same test passes post-fix |
| Existing suites re-run | 5 files / 112 tests passed (15 gen+writer, 22 plan_gen_contract+compose+verify, 39 wire+step_runner+run_command, 36 runner+verify_red+runner_suite) |
| Mutation gate | not_assessed (mutation_test not in scope for a CLI behavior fix; deliberate-mutant sampling below) |
| New smells introduced | none (fix reuses the existing writer/registry contract, no new abstractions) |

## Red phase (pre-fix evidence)

`dart test test/plugins/tdd/commands/gen_command_test.dart --preset=all --name "binary change"`
on the pre-fix tree (master @ ea399d96 + test only):

```
Actual: 'behavior_id: B-003\n ... ownership: reused/reused\n'
Which: does not contain 'binary updated, stub regenerated'
00:00 +0 -1: GenCommand — stale stub after binary change (bug #683)
  reused/reused with a stub from an OLDER binary regenerates the stub
```

The pre-fix binary returned `ownership: reused/reused` and wrote zero bytes —
the stale stub stayed in place. That is the exact reported failure: after a
binary rebuild, gen skips regeneration and the resumed pipeline regresses.

## Fix (green phase)

- `lib/src/plugins/tdd/commands/gen_command.dart` — after a `reused/reused`
  preflight, gen compares the subject on disk against
  `SubjectWriter.render(behavior)` (the current binary's render, Option B —
  lenient). Differs + still an `UnimplementedError` stub → the pair is
  regenerated and `note: binary updated, stub regenerated` is printed.
  Identical → silent skip (FR-006 preserved). A subject with no
  `UnimplementedError` left is a progressed artifact (func scaffolding /
  implementation) and is never clobbered.
- `lib/src/plugins/tdd/services/subject_writer.dart` — exposes `render()`
  (the write path already used it internally; behavior unchanged).
- Ownership remains `reused/reused` on regeneration: the registry record is
  untouched and the issue's verification criterion expects `reused/reused`
  plus regeneration (or a warning).

## Mutation sampling (deliberate mutants)

| Mutant | Result |
|--------|--------|
| Remove the staleness check entirely (= pre-fix code) | killed — the regeneration test fails (red evidence above) |
| Drop the `UnimplementedError` guard (regenerate progressed subjects) | killed — "a PROGRESSED subject ... is never clobbered" fails: the func-scaffolded implementation would be destroyed |
| Regenerate with a spurious note on identical content | killed — "skips silently (no note, no rewrite)" fails |

## Test-first evidence

| Step | Evidence |
|------|----------|
| RED | failing test committed first; failure output captured verbatim above |
| GREEN | same test passes after `gen_command.dart` + `subject_writer.dart` change |
| REFACTOR | none required (per the bug TDD cycle) |

## Traceability

| Issue criterion | Test |
|-----------------|------|
| "Stub mtime older than binary + reused/reused → stub is regenerated" | `reused/reused with a stub from an OLDER binary regenerates the stub` |
| "No spurious regeneration when binary hasn't changed" | `reused/reused with content identical to the current render skips silently` |
| "Test suite passes after make on resumed run" (no regression) | progressed-subject guard test + run_command/step_runner/runner suites green |

## What was not audited

- The full slow-tier matrix under `--concurrency=4` exhibits load-induced
  flakes in this environment (temp-project subprocess tests contending);
  suites were verified in isolation with `--concurrency=2` and the shared
  chunked runner covers the full tree per repo policy. The flake set is
  unchanged from master (func_command tests pass in isolation).
- End-to-end `zfa tdd run` with a REAL compiled-binary swap (the issue's
  literal scripts/rebuild.sh scenario) was simulated at the content level
  (older-binary stub vs current render) rather than by compiling two
  binaries; the content comparison is the fix's actual mechanism, so the
  simulation exercises the changed code path directly.
- Mutation testing via `mutation_test` was not run (not configured for this
  CLI surface); deliberate-mutant sampling was used instead, as recorded.
