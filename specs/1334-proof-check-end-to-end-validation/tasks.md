---

description: "Task list for 1334-proof-check-end-to-end-validation"
---

# Tasks: zfa proof chain — end-to-end receipt validation with JSON verdict

**Input**: Design documents from `/specs/1334-proof-check-end-to-end-validation/`

**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Organization**: Tasks are grouped by user story; the checker module is
the shared foundation (Phase 2), then each check lands as an independent,
testable slice.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Spec/plan/task artifacts under
      `specs/1334-proof-check-end-to-end-validation/` (this file).
- [x] T002 Toolchain verified: Dart 3.13.3, `dart pub get` resolves.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the verdict model + checker skeleton every check plugs into.

- [x] T003 Create `lib/src/core/proof/proof_chain_checker.dart`:
      `ProofChainSeverity` enum (drift/gap/info), `ProofChainItem`
      (category, severity, file, expected, actual, fix, check),
      `ProofChainCheckKind` enum (six checks), `ProofChainReport`
      (items, per-check counts, ok, exitCode, toJson → `proof-chain.v1`),
      `ProofChainChecker` shell with `check()` orchestrating the six
      checks and infra-error detection (exit 2).
- [x] T004 RED tests first for the model invariants: item JSON carries
      category/severity/file/expected/actual/fix; exit code derivation
      (drift → 1, gap-only → 0, infra → 2); vacuous project → ok with
      zero items (`test/core/proof_chain_checker_test.dart`).

**Checkpoint**: the verdict spine exists; checks can land independently.

## Phase 3: User Story 1 - CI verdict + exit codes (Priority: P1) 🎯 MVP

**Goal**: `zfa proof chain` runs end-to-end with the protocol contract.

- [x] T005 Receipt digest check: compose `ProofChecker.check()` findings
      into `receipt_digest` items (expected = receipted digest, actual =
      current digest, file, fix = the receipt's repro line).
- [x] T006 `ProofChainCommand` in `lib/src/commands/proof_command.dart`
      (NEW subcommand `chain`; `--json`, `--run-tests` flags; text mode
      with per-check counts, item lines, `--> fix:` lines, final
      `proof-chain:` verdict line; exit 0/1/2). Register in
      `ProofCommand()` constructor; update the group help to list both
      subcommands; `proof check` code paths untouched.
- [x] T007 CLI contract tests (`test/commands/proof_chain_command_test.dart`,
      `runZfaSource` subprocess pattern): clean project → exit 0 + JSON
      parse; drifted receipt → exit 1 + `receipt_digest` item;
      `--json` → one parseable object; infra (receipts dir replaced by a
      FILE) → exit 2.
- [x] T008 [P] Regression guard: existing `proof check` tests still pass
      untouched (`test/commands/proof_command_test.dart`,
      `test/core/proof_checker_test.dart`,
      `test/core/proof/proof_check_valid_test.dart`).

## Phase 4: User Story 2 - Behavior coverage (Priority: P1)

**Goal**: every spec behavior's green evidence is accounted for.

- [x] T009 RED tests: green-covered behavior → no item; missing green →
      `behavior_coverage` gap with fix `zfa tdd run <feature>`; green
      evidence naming a missing test file → `test_integrity` drift.
- [x] T010 Implement: enumerate `specs/*/tdd/test-list.md` (TestListReader
      ids; fall back to a minimal markdown-table scan when the list is
      hand-shaped), intersect with `CycleEvidence.greenEvidence()` per
      feature; orphaned-green detection reuses the evidence-vs-disk rule.

## Phase 5: User Story 3 - Generated test integrity (Priority: P2)

**Goal**: registered gen'd tests exist, imports resolve, and can run.

- [x] T011 RED tests: missing registered test file → `test_integrity`
      drift; unresolved import → `test_integrity` drift naming the URI;
      healthy registration → no item; `--run-tests` with injected fake
      runner: non-zero exit → `test_runtime` drift, zero → no item,
      default (off) → info "runtime not exercised".
- [x] T012 Implement: load `specs/*/tdd/artifacts.json`, resolve
      absolute/relative test paths against project root, run
      `unresolvedImports` (the doctor import-resolution seam), execute
      via the injectable runner when `--run-tests`.

## Phase 6: User Story 4 - Route + usecase verifies (Priority: P2)

**Goal**: receipt→verify links are read and judged.

- [x] T013 RED tests: route table + fail verify receipt → `route_verify`
      drift; missing verify receipt → gap with fix; skip-with-reason →
      info; route table without verify infra → gap.
- [x] T014 Implement `RouteVerifyReader`: latest
      `routes-<Entity>-verify.json` per `routes-<Entity>.json` (entity
      set from receipt file names), parse `verdict.ok` / skip markers.
- [x] T015 RED tests + implementation: usecase-create receipt entity
      with healthy tree → no item; conforming-fail entity →
      `usecase_verify` drift; missing artifacts → gap; no receipts →
      vacuous. Compose `UsecaseGate` in-process (already imported by
      `usecase_verify_command.dart` — same seam, no subprocess).

## Phase 7: User Story 5 - Xray coverage traceability (Priority: P3)

**Goal**: ledger kinds are traced or named.

- [x] T016 RED tests: ledger row with green prover → traced; row without
      green prover → `xray_coverage` gap naming kind+surface; no ledger
      file → no items.
- [x] T017 Implement: parse `specs/*/tdd/ui-ledger.md` tables (surface,
      kind, provers), recompute traced-ness against the feature's green
      set, report untraced kinds.

## Phase 8: Non-behavioral (implement) + hardening

- [x] T018 Read-only guarantee: no store mutation in any check (assert
      file mtimes/contents unchanged across a run in one unit test).
- [x] T019 Hermeticity: default `check()` spawns zero processes
      (injectable runner defaults to a real spawner only under
      `--run-tests`).
- [x] T020 Docs: `zfa proof` group description + `chain` subcommand
      help cross-reference `check` (#807) and the chain's exit-code
      table; README proof section updated with the CI one-liner
      (`zfa proof chain --json` before `flutter test`).

## Verification

- [x] T021 `dart analyze` clean on changed files.
- [x] T022 Targeted `dart test` green: the two new test files + the
      three existing proof test files (regression).
- [x] T023 `dart run bin/zuraffa.dart proof chain` on a clean sandbox →
      exit 0; `--json` → `jsonDecode`-valid; drifted sandbox → exit 1;
      exit-code demo recorded for the PR body.
- [x] T024 `dart format .` leaves zero diffs; disk housekeeping pass.
