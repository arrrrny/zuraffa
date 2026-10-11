**Template Version**: `zuraffa-1.0`

# Plan: 1652-refactor-digest-gate

**Branch**: `feat/1652-refactor-digest-gate` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/1652-refactor-digest-gate/spec.md` (issue #1652, perf)

## Summary

On a forward `zfa tdd run`, behavior k's phase-1 refactor spawn follows
behavior k's make-green with zero external edits in between — yet it
re-pays the full pipeline (full-suite preflight + pass registry +
re-proof, ~26 s/behavior on the probe). The #1588 ledger cannot inherit
here because forward progress changes `lib/` on every make: each spawn's
tree differs from the LAST REFRACTOR's proved tree. What it DOES equal is
the THIS MAKE's certified post-state — and make just ran its live green
evidence on exactly that tree. The fix: the driving run records make's
certified post-state (context keys + `lib`/`test` byte digests + green
verdict) at every make-green, and a `--pass-batch` refactor spawn whose
tree and gate context match that record inherits the pipeline — the same
inherit semantics, evidence shape, and fallback rules as the #1588
ledger hit, one record earlier in the chain.

## Technical Context

- Language/Dart SDK: `^3.11.0` (repo pin), running on Dart 3.13.3 stable
  (macOS arm64 this session). Pure-Dart root package.
- Surfaces modified:
  - `lib/src/plugins/tdd/services/make_post_state.dart` (NEW) —
    `MakePostState`: the record type + read/write/matches, reusing
    `PassBatchLedger`'s static helpers (`treeDigest`, `baselineKeyFor`,
    `configKeyFor`) and `TreeSnapshot.capture` so both sides of the
    comparison share one implementation. File:
    `<featureDir>/tdd/make-post-state.json`.
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` — after a make
    step green-applies at a `batchRefactor`-enabled call site (phase-1;
    a new `recordMakePostState` flag covers the phase-2a re-attempt),
    best-effort write of the record (warning-only on failure). Helper
    `_recordMakePostState`.
  - `lib/src/plugins/tdd/commands/refactor_command.dart` — inside the
    existing `if (passBatch && !fullReproof)` block, after the #1588
    ledger miss: a `MakePostState` hit inherits the pipeline (same
    outcome/cycle-log/summary shape as the ledger hit, naming the make,
    the capture time, and that the full suite did not run at this tree).
- Surfaces NOT modified (hard constraints):
  - `make_command.dart` — untouched; make never reads or writes the
    record (the driver owns it; FR-005/FR-007).
  - `PassBatchLedger` + `pass-batch.json` semantics — untouched; the
    refactor-proved full-pipeline gate keeps precedence, the new record
    never overwrites it (FR-007).
  - The standalone (flag-less) refactor path — untouched (FR-005).
  - Phase-2b batch pass, `zfa tdd verify` preflight, corpus lane — the
    full-suite gates keep their existing frequency (spec 069 T001).
- Test seams (existing, reused): the #1588 command-level harness
  (CliRunner + TddFixture + a logging suite wrapper that counts real
  `dart test` spawns) and the run_command_test driver-level harness
  (scripted fake zfa; assert the record is written on make-green and
  the refactor spawn argv carries the driver-only flags).

## Design

### 1. The record (`MakePostState`)

```json
{
  "captured_at": "<iso-8601>",
  "behavior_id": "U2",
  "suite": "<suite template>",
  "baseline_key": "<sha256 of the --suite-baseline bytes, or ''>",
  "config_key": "<sha256 of dart_test.yaml + pubspec.lock>",
  "exempt_behaviors": ["..."],
  "lib_digest": "<sha256 of the sorted lib/ fingerprints>",
  "test_digest": "<sha256 of the sorted test/ fingerprints>",
  "green_verdict": "make U2 outcome=green exit 0 (post-generation green evidence)"
}
```

`matches({suite, baselineKey, configKey, exemptBehaviors, libDigest,
testDigest})` — identical context comparison to `PassBatchLedger.matches`
(order-insensitive exempt list). Corrupt/mistyped/missing → null → miss →
full pipeline (safe failure, mirroring the ledger).

### 2. The driver records at make-green

In `_driveBehavior`'s step loop, at the same hook point as the existing
gen-warning forward:

- `step == 'make' && result.success && recordMakePostState` → write the
  record: suite template via `SingleTestRunner.loadSuiteTemplate`,
  digests via `TreeSnapshot.capture(projectRoot, trees: ['lib'/'test'])`,
  baseline key from the `suiteBaselinePath` the run already threads,
  config key from `projectRoot`, exempt set = the blocked ids (the same
  computation `_refactorBatchArgs` uses), behavior id + outcome from the
  step result. Any error → one warning line, no state change (FR-006).
- Phase-2a's re-attempt call site passes `recordMakePostState: true` so
  a re-attempted make also records; phase-2b has no make steps.
- The #741 already-green skip writes nothing — the standing record still
  describes the certified tree and inherits honestly if it still matches.

### 3. The refactor fast path

In `refactor_command.dart`, still under `passBatch && !fullReproof`,
after the ledger miss:

- `MakePostState.read(featureDir)` + context match → inherit: outcome
  clean, exit 0, cycle-log no-op entry whose captured output names the
  behavior + capture time + green verdict, states plainly that the
  preflight/pass registry/re-proof were skipped because the tree is
  byte-identical to the make's certified post-state, that the evidence
  is make's post-generation green evidence (the full suite did NOT run
  at this tree), and that the full gate still runs at feature completion
  + nightly. Stdout prints the same facts with an `issue #1652` marker.
- The check order is ledger → record: a refactor-proved gate (full
  pipeline evidence) always outranks a make-certified post-state.

### Safety argument (the issue's, made testable)

Between make-green and the phase-1 refactor spawn the run performs only
in-`featureDir` bookkeeping (run-state, evidence, cycle log) — no
`lib/`/`test/` writes. The digest comparison makes that claim checkable:
if anything external DID touch either tree, the digests differ and the
full pipeline runs (A2). The inheritance drops the preflight's redundant
re-run, not the gate: the full suite still gates at phase-2b, feature
completion, and nightly, and a cross-behavior regression from behavior
k's make surfaces there honestly — one gate later than before, at N→1
cost instead of N×N.

## Alternatives rejected

- Proposal 1 — defer phase-1 refactor into the phase-2b batch pass:
  changes the refactor's scheduling contract (per-behavior refactor
  evidence disappears from the mid-run cycle log; every stop/resume path
  that assumes a behavior leaves phase-1 fully green must be re-audited)
  to save what the digest gate saves with zero contract change.
- Proposal 3 — scope the preflight to the behavior's registered test +
  make target: weakens the gate by heuristic (a scoped suite proves less
  than today's full suite for spawns that DO need re-proving — the drift
  and mismatch cases). The digest gate proves the same full gate is
  inherited, not a reduced one.
- Reusing `pass-batch.json` for make's record: conflates two different
  proofs. The ledger's verdicts mean "a refactor ran the full pipeline
  on this tree"; make's evidence is a post-generation target test. A
  separate record with its own honest verdict keeps both provenance
  chains clean (FR-007) and keeps `make_command.dart` out of the diff.
- Recording the digest inside make_command: expands the make contract
  and its test surface for what the driver can observe itself after the
  spawn returns; the driver-side write keeps make untouched.

## Verification

- Red tests first (see `tdd/test-list.md`), two tiers:
  - Command level (the #1588 harness): inheritance hit (zero suite
    spawns), each mismatch dimension re-runs the pipeline.
  - Driver level (fake zfa): the record is written on make-green with
    tree-matching digests; a failed write is a warning, not an error.
- `dart analyze` on changed files: zero findings; `dart format` clean.
- data-model.md: not generated — the record IS the data model, specified
  in-plan (one JSON document, no entities, no relationships).
- contracts/: not generated — the CLI surface gains a driver-only
  consumed record file; no public interface change.

## Constitution Check

`.specify/memory/constitution.md` is an unfilled template — no gates to
evaluate. Repo de-facto constraints honored: red-before-green evidence,
the #1588/#1624 frequency-engineering line (full gates stay at phase-2b/
completion/nightly), honest evidence naming for every inheritance,
safe-failure fallbacks on all derived data.
