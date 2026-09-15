**Template Version**: `zuraffa-1.0`

# Spec: 1653-mutation-test-opt-in-pre-resolve

GitHub issue: arrrrny/zuraffa#1653 (perf: first refactor after
`zfa tdd init` took 8m32s on a 2-file package — init's unconditional
`mutation_test`+`coverage` dev-deps defer a multi-minute cold cost into the
first analyze-class pass; #1637 checked, not reproduced)

## Summary

The first refactor after `zfa tdd init` took **8m32s** on a two-file
pure-Dart package (zcalc probe) — versus **26s** for the identical
standalone refactor on the same tree minutes later. The whole feature's
hand-written equivalent is ~2 minutes end to end. The prime suspect is the
`zfa tdd init` writer sequence (run automatically as the #1528 preflight
inside the first `zfa tdd run`): `PubspecDevDependenciesPatcher` injects
`mutation_test: ^1.8.0` into EVERY project's pubspec as an unconditional
testing dev_dependency. `mutation_test` is an analyzer-versioned package
with a large transitive graph, so the first analyze-class pass after
injection pays a cold multi-minute cost — dependency download/resolution
plus first analysis over the enlarged package config — on a package whose
own code is two files. The cost did NOT reproduce on subsequent refactors
(26–44s), consistent with a one-time warm of the pub/analyzer caches — but
it recurs for every fresh project and every fresh CI agent.

Related checks: #1637 (mtime-refreshed pubspec.lock) does NOT reproduce on
current master via the standalone refactor path. Related context: #1528
(preflight), #1590 (silence class), #1529 (per-step budget).

## Locked decisions

1. **Opt-in, not unconditional (Ask 1, option a).** `mutation_test` leaves
   the DEFAULT baseline injected by `zfa tdd init` and by the #1528
   preflight auto-init. Opt in with `zfa tdd init --mutation` — the flag
   threads a `mutation` switch through `TddBaselineInit.ensure` into
   `PubspecDevDependenciesPatcher(includeMutationTest: true)`. The pin
   stays `^1.8.0` (the bug #755 verifier-compatibility contract is
   unchanged). Re-running `zfa tdd init --mutation` on an already
   initialized project adds the missing dep idempotently (the patcher only
   adds absent entries — FR-008 skip-if-present discipline preserved).
   The lazy add-on-first-verify alternative (Ask 1, option b) is NOT
   taken: it would side-effect a pubspec write + resolver spawn inside the
   verify lane, which the issue's hard constraint protects ("fix the init
   injection and timing only; do NOT change the verify lane logic").
   Verify's existing NOT_ASSESSED + `dart pub add dev:mutation_test`
   fix-line remains the honest degradation for a project that never opted
   in.
2. **`coverage` stays unconditional.** The issue names `mutation_test` —
   the analyzer-versioned package with the large transitive graph — as the
   prime suspect. `coverage` is a small pure-Dart dep the coverage lane
   consumes; moving it is out of scope and riskier than the cost it saves.
3. **Pre-resolve at init time (Ask 2).** When init's dependency writers
   newly added ANY dependency entries (dev_dependencies, the #1349 app
   module deps, or the #1260 skin dep), init itself spawns the project's
   resolver (`dart pub get`, or `flutter pub get` for a Flutter target)
   under a hard deadline and PRINTS the duration. The cold cost is paid at
   init time — loudly, visibly — instead of being deferred into the first
   refactor inside a run. An idempotent pass that added nothing does NOT
   re-run the resolver (SC-4: no repeated network/cache cost on every
   init).
4. **Fail-closed on a real resolution failure.** A resolver that RAN and
   exited non-zero is a writer failure → `BaselineInitMisfire` → the #1528
   preflight fail-closes with `setup-error`. A baseline whose deps cannot
   resolve is not a working baseline; driving a loop against it would
   rediscover the failure later, with worse diagnostics (the exact
   deferred-surprise class this issue removes). A resolver binary that
   CANNOT be found (e.g. no `flutter` on PATH for a Flutter target) warns
   loudly but does not misfire — nothing was proven broken, the
   environment may resolve elsewhere.
5. **Per-phase durations in the refactor receipt (Ask 3).**
   `RefactorCommand` measures preflight (the absolute-green suite run),
   registry (the fixed pass batch), and re-proof (including #1333 retry
   attempts, summed wall time), prints a `phase timings:` line on the
   green path, and records the durations in the cycle-log receipt. Each
   pass action additionally records its own wall duration — the stuck-step
   signal inside the registry phase. The FR-009 summary line contract
   (`refactor: feature=<f> outcome=<o> applied=<n>`) is UNCHANGED: timings
   ride an additional stdout line, never the contract line.
6. **Evidence schema stays v1.** The durations render as ADDITIVE optional
   lines outside the chain-hash payload — `- phases:` on the refactor
   entry, `  duration:` inside the `actions:` block — exactly the
   `- outcome:` / `- subject-hash:` / #1587-note precedents. Legacy
   entries stay parseable; the doctor's chain recompute is untouched.
7. **One PR, init injection + timing only.** The verify lane's audit
   semantics (spec 044, FR-012..023), the mutation gate, and the
   `mutation_test` tool itself are untouched. Hard constraint honored.

## Functional requirements

- **FR-1**: `PubspecDevDependenciesPatcher` gains `includeMutationTest`
  (named parameter, DEFAULT FALSE); when false, neither
  `flutterDevDependencies` nor `dartDevDependencies` injects
  `mutation_test`; when true, the writer adds `mutation_test: ^1.8.0`
  exactly as before. The static maps keep their `mutation_test` entries
  (the #755 pin contract is asserted unchanged).
            traces: PubspecDevDependenciesPatcher
- **FR-2**: `TddBaselineInit.ensure` gains `mutation` (default false) and
  threads it to the patcher; the #1528 preflight keeps the default
  (non-mutation) auto-init.
            traces: TddBaselineInit
- **FR-3**: `zfa tdd init` exposes `--mutation` (negatable: false) whose
  only effect is forwarding the opt-in to `ensure`.
            traces: InitCommand
- **FR-4**: when the dependency writers newly added entries, init runs the
  target's resolver with a hard deadline, prints
  `✓ pub resolution: <command> (<elapsed>)`, and returns; when nothing was
  added, the resolver does not spawn.
            traces: TddBaselineInit
- **FR-5**: a resolver run that exits non-zero fails the init sequence
  (misfire naming the resolver output); a missing resolver binary warns
  loudly and does not fail the sequence.
            traces: TddBaselineInit
- **FR-6**: `RefactorCommand` measures the three phases and prints
  `phase timings: preflight=<d> registry=<d> re-proof=<d>` on the green
  path; the FR-009 summary line format is byte-unchanged.
            traces: RefactorCommand
- **FR-7**: the refactor cycle-log entry renders
  `- phases: preflight=<d> registry=<d> re-proof=<d>` and each recorded
  action renders `  duration: <d>`; both lines are additive and outside
  the chain-hash payload (schema v1 preserved).
            traces: CycleLogEntry
- **FR-8**: `RefactorPasses` records each pass's wall duration into its
  `RefactorAction` (null for a scheduling-skipped pass — nothing ran).
            traces: RefactorAction

## Acceptance scenarios

1. **Given** an empty pure-Dart project, **When** `zfa tdd init` runs with
   default flags, **Then** dev_dependencies gain the testing baseline
   WITHOUT `mutation_test`.
   **Type**: acceptance
2. **Given** the same project, **When** `zfa tdd init --mutation` runs,
   **Then** `mutation_test: ^1.8.0` is present.
   **Type**: acceptance
3. **Given** a project where init just added dev_dependencies, **When**
   init finishes, **Then** the resolver ran at init time and its duration
   was printed; **And** when init runs again adding nothing, the resolver
   does not spawn again.
   **Type**: acceptance
4. **Given** a green refactor on a fixture project, **When** the receipt
   is appended, **Then** the entry carries preflight/registry/re-proof
   durations and every executed pass action carries its own duration.
   **Type**: acceptance
5. **Given** a resolver that exits non-zero during init, **When** init
   finishes, **Then** init misfires naming the resolver output.
   **Type**: acceptance
6. **Given** a legacy refactor entry without duration lines, **When** the
   cycle-log is re-read, **Then** the entry still parses and the chain
   recompute is unaffected (schema v1 backward compatibility).
   **Type**: acceptance

## Success criteria

- **SC-1**: `mutation_test` is not injected by default (opt-in via
  `--mutation`); the #1528 preflight auto-init behaves identically to
  default init.
- **SC-2**: `zfa tdd init` pays the cold-resolution cost at init time
  whenever it injects deps (resolver spawned + duration printed), and not
  on idempotent passes.
- **SC-3**: the refactor receipt includes per-phase durations
  (preflight/registry/re-proof) plus per-pass durations.
- **SC-4**: a fresh app's first refactor no longer pays the
  `mutation_test` cold-resolution cost — the dep is absent by default and
  nothing in the refactor path injects it (root cause removed; the
  8m32s-deferring warm is no longer queued behind every fresh project).
- **SC-5**: `dart analyze` on the changed surface is clean; `dart format`
  is clean; the writer/plugin suites that touch the changed surface stay
  green.

## Layer Contracts

**Function**:
- `PubspecDevDependenciesPatcher`: `ensure(String, {bool, bool, bool}) -> Future<List<String>>`
- `TddBaselineInit`: `ensure({String, bool, bool, bool, Function, Function, Function}) -> Future<BaselineInitReport>`
- `InitCommand`: `run() -> Future<void>`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| `RefactorAction` | `name: String`, `duration: Duration?` | One recorded pass; gains the per-pass wall duration |
| `CycleLogEntry` | `phases: String?` (rendered) | Refactor receipt row; gains the additive duration lines |
| `BaselineInitReport` | `created: List<String>`, `failures: List<String>` | Unchanged shape; the resolver failure rides `failures` |

## External Dependencies

- `mutation_test` (^1.8.0) — OPT-IN at init from this feature on; the
  verify lane's NOT_ASSESSED degradation for a missing tool is unchanged.

## Assumptions

- The 8m32s probe could not be re-run end-to-end in this environment (no
  Flutter SDK for a real fresh-app probe); the root-cause claim is proven
  at the unit level (default init injects no `mutation_test`) plus the
  issue's own evidence (26s warm reframe). SC-4's ≤60s E2E bound is
  argued, not re-measured — recorded honestly in the verification.
- The pre-resolve deadline is `TddTimeouts.defaultPipelineStep`
  (10 minutes): generous by design, the same class as every other TDD
  subprocess bound.
