# TDD Verification — Spec 1354 simulate scenario subcommands honor the pinned feature

**Verdict: PASS** (audited 2026-09-09, cold context, LLM-guided audit —
the repo itself is not zuraffa-wired, so `zfa tdd verify` could not run;
every gate below was checked by hand with real evidence).

## Gate 1 — Test-first evidence: PASS

- Git history: `94eba196 test(1354): certified red — bare simulate
  subcommands must resolve the pinned feature (B1-B8)` contains ONLY the
  test file; running it at that commit against the unfixed library gives
  `+2 -6` (B1/B3/B4/B5/B7/B8 red; B2/B6 are precedence guards declared
  GREEN pre-fix in the red protocol). The implementation landed in the
  NEXT commit only after the suite went green.
- Cycle log: `tdd/cycle-log.md` records the RED run (with the observed
  counts and per-behavior signatures) before the GREEN run.

## Gate 2 — Suite state: PASS

- Feature file: `dart test test/simulation/worlds/simulate_worlds_command_test.dart`
  → `+25 All tests passed!` (B1–B8 + the 17 pre-existing spec-968 tests).
- Regression pin (scoped, never the full suite — disk ceiling):
  `simulate_command_test.dart` + `simulate_skin_command_test.dart` +
  all of `test/simulation/worlds/` → `+123 All tests passed!`
- `dart analyze` on the touched files → No issues found; `dart format`
  → zero remaining diffs.

## Gate 3 — Test strength (deliberate-mutant sampling; no mutation tool
wired per the tdd profile): PASS

| Mutant | Change | Result | Killed by |
| ------ | ------ | ------ | --------- |
| M1 | `_readPinnedFeature` returns null (fallback removed) | KILLED — `+4 -4` | B1, B4, B5, B7 |
| M2 | explicit/parent `--feature` ignored (pin always wins) | KILLED — `+5 -3` | B2, B5, B6 |

0 mutants survived. No test was weakened or deleted to make a mutant pass.

## Gate 4 — Test smells: PASS

- No conditional logic or try/catch in tests; every expect carries a
  reason string naming the contract it pins.
- No inter-test coupling: each test builds its workspace in setUp/inline
  (`Directory.systemTemp`), torn down in tearDown/addTearDown.
- Behavior names are observable-outcome sentences matching the test-list
  ids (B1–B8) 1:1.
- Exit codes asserted against the SPEC 917 canonical usage code (2), not
  raw numbers invented per test.

## Gate 5 — Acceptance-criteria coverage: PASS

| Spec criterion | Behavior | Evidence |
| -------------- | -------- | -------- |
| AS-1 / FR-1 / SC-001 | B1 | bare init == explicit twin (byte-identical manifest) |
| AS-2 / FR-2 | B2 | explicit beats pin; pinned feature untouched |
| AS-3 / FR-4 / SC-002 | B3 | exit 2, both missing inputs named, no `specs/` writes |
| AS-4 / FR-4 | B4 | dangling pin named (exit 2, never a scan) |
| AS-5 / FR-3 | B5 | run/certify/verify-world resolve the pin to green twins |
| AS-6 / FR-5 | B6 | parent-level flag regression guard |
| FR-4 (malformed pin) | B7 | malformed pin named, no crash |
| FR-5 (docs) | B8 | `simulate init --help` carries the pinned-default wording |
| SC-003 (explicit form unchanged) | M2 kills + pre-existing 17 tests | zero drift |

## Live repro proof (issue #1354's exact command)

In a scratch workspace with `.specify/feature.json` pinned to
`specs/968-simulation-worlds` (CWD resolution, no `--feature`, no
`--project`):

```
$ zfa simulate init test_world
SIMULATE init -> GREEN world=.../specs/968-simulation-worlds/tdd/worlds/test_world.world.json scenario=test_world feature=968-simulation-worlds touchpoints=2 certified=4 world-hash=a00de31f95fe
EXIT=0
```

`world-hash=a00de31f95fe` matches the issue's workaround evidence
(`touchpoints=2, certified=4, world-hash=a00de31f95fe`) — the bare
invocation now produces byte-identical proof to the explicit form.

## Remediation tasks

None — no surviving mutants, no gaps.
