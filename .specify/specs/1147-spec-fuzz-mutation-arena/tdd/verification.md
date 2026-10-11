# Verification — 1147-spec-fuzz-mutation-arena

- **Date**: 2026-09-18
- **Branch**: `feat/1147-spec-fuzz-mutation-arena`
- **Toolchain**: Dart SDK 3.13.4 (stable), linux_x64; `specify` CLI
  1.0.9.dev0, TDD Extension v1.1.2 (`specify extension list` →
  "✓ TDD Extension")
- **Scope audited**: `spec.md` (SC-1..SC-6, the issue #1147 hard
  constraints), `plan.md`, `tdd/test-list.md`, `tdd/cycle-log.md`, the
  changed code (`lib/src/plugins/tdd/commands/spec_fuzz_command.dart`,
  `lib/src/commands/spec_command.dart`), and the new fast-tier suite
  (`test/commands/spec_fuzz_command_1147_run_semantics_test.dart`).
- **Provenance**: `/speckit.tdd.verify` Step 0 — `zfa --version` →
  `zfa v6.3.0`; `.zfa.json` absent → the command's own protocol routes to
  the guided audit path. Every evidence line below is from a run executed
  in THIS session (commands + verbatim verdicts in `tdd/cycle-log.md`);
  nothing is copied from a prior session.

## Verdict

VERIFIED for this spec's surface. The six issue constraints are pinned
at the command boundary by the new fast-tier suite (8/8), the untouched
0967 suites stay green (50/50; 58/58 combined), and the real-process
lanes re-run in this session prove the referee end to end: the strong
round kills 13/13 mutants with per-pin evidence and exits 0; the replay
is byte-identical; the weak round's survivors are reported as proven
spec weaknesses with evidence and a non-zero exit.

| id | criterion (issue #1147 hard constraints) | verdict | evidence |
|----|-------------------------------------------|---------|----------|
| SC-1 | the five operators apply deterministically and replayably | PASS | A-1147-b4 green (all five operators produce candidates against the all-element fixture); A-1147-b7 green (same seed+budget → byte-identical `spec-fuzz.json`); real-process strong round replay `cmp` → "REPLAY: byte-identical"; the mutator suite (25 pins) stays green untouched |
| SC-2 | re-run behaviors against the mutated spec | PASS | the P2 pin fired in the real-process strong round: `SM-002 swap-literal killed — P2:loop-red regenerated test failed (exit 1): Expected: <43>` (real `dart test` spawn of the regenerated test against the committed subject); A-1147-b1/b2 drive the same auditor path |
| SC-3 | classify killed vs survived with evidence | PASS | real weak round: 3 survived rows each name the silent pins ("no committed assertion pins the original value(s) Hello"); real strong round: 13/13 killed rows name the firing pin (P3 with file:line, P2 with exit code + expected) |
| SC-4 | emit the machine-readable report in the documented shape | PASS | A-1147-b3 green: rows carry `{mutation_id, spec_line, operator, verdict, evidence}` under `schema: spec-fuzz.v1`, ids `SM-###`, positive spec lines, non-empty evidence; the report is written to `specs/<feature>/tdd/spec-fuzz.json` (+ markdown twin) |
| SC-5 | exit 0 when all killed / non-zero when survived > 0 | PASS | A-1147-b2 green (strong → exit 0, certified=true); A-1147-b1 green (weak → exit 1); real-process strong round EXIT=0; real weak round exits non-zero (refusal class while not_assessed rows exist — an honest non-zero, never a fake pass) |
| SC-6 | respect `--budget N` | PASS | A-1147-b6 green: `--budget 2` judges exactly 2 of a larger candidate set and records `budget=2`; usage-class budget refusals pinned by the pre-existing command suite (non-integer / <1 refused, untouched) |

## Changed code (minimal delta)

`lib/src/plugins/tdd/commands/spec_fuzz_command.dart` — optional
`runPreflight`/`spawnTest` constructor seams (the auditor's own
MutationAuditor-pattern typedefs), forwarded to both auditor
construction sites; the command body, flags, gate precedence, exit
protocol, and corpus path are unmodified. `lib/src/commands/spec_command.dart`
— the same two optional params forwarded to the fuzz subcommand. With
the default construction (CliRunner wiring) the seams are null and the
behavior is byte-identical to the pre-fix tree: the 0967 suites pass
unmodified.

## Gates

- `dart analyze` on the three changed Dart files → `No issues found!`
- `dart format .` → 1 file adjusted (the new test); re-run
  `--set-exit-if-changed` on the changed files → `0 changed`, exit 0
- Combined fuzz lane → `00:11 +58: All tests passed!`
- Restoration in every real round → `restoration_verified: true`

## Flagged (pre-existing, not this branch)

`test/plugins/tdd/spec_fuzz_demo_test.dart` (slow tier) fails
identically on this branch and on a pristine `master` worktree
(a9329746): the demo fixture's traces-less shape yields deterministic
`ids shifted` not_assessed rows, so its weak-round assertion
(`exitCode == 1`) sees the honest refusal exit 2. Predates 1147; the
"do NOT change existing tdd run semantics" constraint puts the 0967
fixture machinery out of scope here. Remediation pointer for the
maintainer: give the demo fixture `traces:` lines (the auditor fixture
shape) or relax its not_assessed expectation.

## Remediation tasks

None open for this spec's surface.
