# Technical Plan: 0967-spec-mutation-arena

## Problem

`zfa tdd verify` mutates CODE and asks "do the tests detect it?" (#811 lineage). Nothing
mutates the SPEC and asks "does the harness pin the intent?" (VISION §7: Agent C
adversarially mutates the spec; zfa referees). Today every green feature's claim "tests
pin intent" is unverified — spec quality is graded by the same machine that consumes the
spec. The missing third leg (after #811 code mutation and #805 generator differential)
is mutation testing for intent: apply deterministic spec mutations, re-run the loop, and
report which mutants still go green. A survived mutant is a proven spec weakness; the
corpus kill rate is the coverage metric presence counts cannot fake.

## Constraints

- One PR (hard constraint from the issue).
- Mutation operators are declared per contract element (Then clauses, FR statements,
  edge-case scenarios, MUST-NOT clauses, literals/routes/keys/ranges) — never free-text
  edits; deterministic and replayable (#806 composes).
- The oracle must be honest within the repo's real machinery: the loop's pins are the
  plan-gate chain (ingest gates), the gen pair (BehaviorTestWriter/SubjectWriter), and
  the committed test suite. No new parallel grammar.
- Mirror `zfa tdd verify`'s honesty contract (spec 044 FR-013..023): green-suite
  preflight first; infra failure = not_assessed never pass; byte-exact restoration with
  sha256 verification; never edit tests to fake a verdict; exit non-zero on any
  non-PASS gate; machine summary line as the CI contract.
- Ledger integration must reuse GapLedgerStore's existing schema (expected_result in
  {complete, pass, behavior}; severity 'contract' per #1007) — no schema changes.
- Pure-Dart default runner; `--runner`/profile resolution mirrors issue #1044.

## Design

### 1. The oracle (what "killed" means)

For each mutant, in a capture/restore round over spec.md (+ the one regenerated test
file):

- **P1 plan-gate pin** — the mutated spec string fails the ingest gate chain
  (template-version treaty, `SpecParser.parse`, coverage gate, declaration refusals,
  undeclared-dependency lint). Evidence: the rejecting gate + spec line.
- **P2 loop-red pin** — the affected behavior's test is REGENERATED from the mutated
  spec with the real `BehaviorTestWriter` (written in place, restored after) and run
  (`dart test <file>` under the resolved runner). Non-zero exit = RED = killed.
  Load-failure / timeout = not_assessed for that mutant (infrastructure, never a kill).
  Acceptance-lane behaviors are invocation-only by construction, so P2 is judged on the
  regenerated file the same way gen would write it.
- **P3 assertion pin** — the mutated element's ORIGINAL values (literals, numbers,
  routes, keys, range bounds) appear inside an `expect(` line of the feature's
  committed test files. For the drop operator, the dropped behavior's own test is
  excluded: the re-plan orphans it, and a pin nothing requires is not a pin.

survived = all three pins silent = the mutated spec still goes green = the test suite
does not pin the intent. This is the issue's sentence, made executable.

### 2. Operators (`services/spec_mutator.dart`, pure)

Candidates are generated in document order from `RequirementScanner` (statement
lineNo addresses) + the scenario-block walk (`_extractAcceptance`'s buffer logic):

- **weaken** (Then clauses only): strip the assertion-bearing specifics — quoted
  literals (`'x'`/`"x"`) and backticked tokens become `something`, numbers become
  `a number`. Candidate only when the Then actually carries specifics.
- **drop** (edge-case scenarios): delete a scenario block (header through the next
  Given header / markdown heading / FR bullet / EOF, trailing blanks trimmed) whose
  block text matches the edge-case vocabulary (error|invalid|empty|fail|failure|
  boundary|timeout|offline|exceed|limit|malformed|denied|reject|negative|overflow).
- **swap-literal** (Then + FR lines): one candidate per token occurrence — quoted
  literals, backticked tokens, route tokens (leading `/`), dotted key tokens
  (two-plus lowercase segments, extension stoplist excluded), numbers (n -> n+1).
  Values become `<value>-swapped`.
- **widen** (Then + FR lines): `N..M` ranges -> `N~/2 .. M*2`; `at most/up to/no
  more than/within N` -> `N*2`; `at least N` -> `N~/2`.
- **drop-must-not** (FR lines): remove the `MUST NOT ...` clause (to the sentence
  boundary); the clause's values are recorded for the P3 scan.

`SM-###` ids are assigned in document order (stable across operator filters).
Application is line-surgical (SpecMigrator pattern): `lines[i] = mutated` / block
deletion, then rejoin.

### 3. Selection: budget + seed

Candidates beyond `--budget N` are selected by a seeded shuffle (`Random(seed)`;
seed 0 = document-order prefix). The report records seed, budget, candidate count,
and the selected ids; given the same seed the round is byte-identical (no
timestamps/wall-clock in report bodies — the ledger keeps its own timestamps).

### 4. The referee (`services/spec_fuzz_auditor.dart`)

Mirrors `MutationAuditor`'s shape and injectable seams (`runPreflight`, `spawnTest`,
ledger store, clock-free report): MutationScope.derive -> preflight (one suite spawn,
green required, else preflight_red) -> per-mutant (P3 pre-scan on committed bytes ->
apply mutation -> P1 gate chain -> P2 regen+spawn when the behavior's description
changed and its id is registered -> restore+verify) -> ledger appends (deduplicated
on unresolved feature+mutation_id) -> WeaknessReport -> gate decision (precedence:
notAssessed > preflightRed > failSurvived > pass; certified = pass && mutations > 0).

### 5. Command surface (`commands/spec_command.dart` + `commands/spec_fuzz_command.dart`)

`zfa spec fuzz <feature>` with `--operators --budget --seed --json --project --timeout
--runner --no-ledger --corpus <target>`. Pre-gates mirror verify: traceability drift
(exit 3), scope emptiness (not_assessed), preflight red. Corpus mode: requireCatalog ->
never-stop iteration under one global budget -> per-feature reports + persisted round
state under `.zfa/corpus/spec-fuzz/<target>.json` -> tally line -> exit 1 when any
feature failed. Registered once in `CliRunner._addCoreCommands()` (the CorpusCommand
no-plugin pattern).

### 6. Reports

`tdd/spec-fuzz.json` — machine rows `{mutation_id, spec_line, operator, element,
original_values, verdict, evidence, pins}` + summary + gate + certified + restoration +
ledger ids. `tdd/spec-fuzz.md` — human twin (gate, round parameters, mutation table,
survivor fix lines, restoration proof). Machine summary line:
`spec-fuzz: feature=... mutations=... killed=... survived=... not_assessed=...
budget=... seed=... fuzz_was_run=... certified=...`.

### 7. Seeded weakness demo (the acceptance proof)

A pure-Dart toy feature (`demo-greeter`) in a temp project: 5 behaviors, real
`dart test` spawns. WEAK spec: every Then vague, no FR pins — every mutant survives,
exit 1, ledger gaps appended. STRENGTHENED spec (same implementation): numbers and
literals that the writer's heuristics pin (`return 42` -> `equals(42)`), FR-002's
`MUST NOT return 42` clause pinned by U1's assertion, the edge-case A2 pinned by
FR-002's `equals(0)` — every mutant killed, exit 0. Shipped twice: as a slow-tier
integration test (`test/plugins/tdd/spec_fuzz_demo_test.dart`) and as
`tools/spec_fuzz_demo.sh` wired into a new `spec_fuzz` CI job (fail-on-should-be-red,
proof_smoke.sh style).

## Files

- `lib/src/commands/spec_command.dart` — the `zfa spec` group.
- `lib/src/plugins/tdd/commands/spec_fuzz_command.dart` — the verb.
- `lib/src/plugins/tdd/models/spec_mutation.dart` — operator/verdict/gate/report models.
- `lib/src/plugins/tdd/services/spec_mutator.dart` — pure generation + application.
- `lib/src/plugins/tdd/services/spec_fuzz_auditor.dart` — the referee.
- `lib/src/cli/cli_runner.dart` — one-line registration.
- `test/plugins/tdd/services/spec_mutator_test.dart`,
  `test/plugins/tdd/services/spec_fuzz_auditor_test.dart`,
  `test/commands/spec_fuzz_command_test.dart`,
  `test/plugins/tdd/spec_fuzz_demo_test.dart` (slow tier).
- `tools/spec_fuzz_demo.sh`, `.github/workflows/ci.yaml` (spec_fuzz job).
