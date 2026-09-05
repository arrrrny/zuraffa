feature: 1108-di-verify-json-envelope (issue #1108, branch fix/1108-di-verify-json-envelope)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at fix/1108-di-verify-json-envelope (base 512a8189) + this session's real runs
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 4/4 # deliberate mutants, no mutation tool in the repo's CI profile; all caught, restoration verified (suite re-green +11 after each revert)
mutants_survived: 0
suite: fast tier chunked 82 chunks (76 PASS / 4 SKIP no-fast-tier / 2 FAIL) — 3222 test-passes / 3 test-failures; all 3 failures PROVEN pre-existing at base 512a8189 by stash-runs (cache ×2 deterministic, state golden ×1 flake, reproduced twice at base); di chunk +11/11; dart analyze 333 issues = base 333 (zero new); dart format --set-exit-if-changed exit 0
method: /speckit.tdd.verify fallback (engine detection ZFA_MISSING — .zfa.json absent in this repo) — LLM-guided audit per the command file: live red captures, verification-time red re-derivation against the pre-implementation tree, rubric, deliberate-mutant sampling, acceptance-criteria coverage, real CLI smoke; every number above is from a real run in this session

# TDD Verification: di verify --json envelope (bug 1108)

**Verdict: PASS.** All 6 new behaviors have recorded red evidence — the
four envelope/text behaviors failed live through the pre-existing command
tree (2 via package:args refusing the JSON-input `--json`, 1 via the
pre-existing unmodifiable-set crash, 1 via the same crash), the crash
regression test failed with exactly the crash it kills, and the red state
was re-derived at verification time against the pre-implementation tree
(compileError: `Method not found: 'DiVerifyCommand'`, restoration
verified by re-green +11). The full fast tier is green except three
failures proven pre-existing at base (see the honest-failures section),
analysis is count-identical to the base (333), the formatter gate passes,
and all four deliberate mutants were caught.

## Engine detection (the command file's Step 0)

```text
zfa --version    -> zfa v6.1.0   (OK)
test -f .zfa.json -> absent       (ZFA_MISSING)
```

Per `.specify/extensions/tdd/commands/speckit.tdd.verify.md`, ZFA_MISSING
takes the documented **fallback path** (LLM-guided audit), matching the
repo precedent (spec 0974's verification was produced on the same path).

## Behaviors and test-first evidence (red)

Commit granularity on this branch is combined (test + implementation in
one commit — "One PR, minimal fix"), stated openly. The red phase is
therefore proven two independent ways, both real:

1. Live in-session: the test file was written and run BEFORE the
   implementation existed — `+5 -5` (5 pre-existing #974 tests green,
   5 new #1108 tests red) through the then-existing ModularDiCommand →
   CapabilityCommand tree; plus the live CLI reproduction
   (`Missing argument for "--json"`, exit 64).
2. Verification-time re-derivation: with the implementation files
   removed from the tree and the test file kept, the suite fails with
   `Method not found: 'DiVerifyCommand'` (compileError); restoration
   byte-verified by re-running the suite green (+11).

| behavior | test | red classification | red exit | proven |
|---|---|---|---|---|
| B1 positive `--json` envelope (exact canonical schema) | di_verify_test `positive: --json emits exactly one envelope line...` | usageRefusal (`--json` was JSON-input; args error exit 64) | 64/1 | PROVEN |
| B2 negative `--json` envelope (findings kind/file/member/fix) | di_verify_test `negative: --json envelopes the dangling findings...` | usageRefusal | 64/1 | PROVEN |
| B3 dead-import envelope (member + details.deadImports) | di_verify_test `negative: a dead import lands in findings[].member...` | usageRefusal | 64/1 | PROVEN |
| B4 text mode unchanged (no `--json`) | di_verify_test `text mode (no --json) is unchanged...` | runtimeCrash (R1 unmodifiable-set) | 1 | PROVEN |
| B5 wiring (manual subcommand replaces CapabilityCommand for `verify`) | di_verify_test `wiring: ModularDiCommand registers DiVerifyCommand...` | compileError at pre-impl tree (`DiVerifyCommand isn't a type`) | 1 | PROVEN |
| B6 crash regression (package-resolved registrations verify green) | di_verify_test `regression (#1108 red): package-resolved registrations must not crash...` | runtimeCrash (R1, verbatim) | 1 | PROVEN |

## Do the tests assert behavior? (rubric Q2)

The envelope tests parse the single stdout line and assert the EXACT
canonical key set (unorderedEquals over the 8 keys — no extras, no
ad-hoc shapes), the schema string, verdict/exit_class pairing, the
subject map, per-finding exact keys (`kind, file, member, fix`), clean
`fix` values (no `-->` marker in JSON), and the details aggregates. The
text-mode test pins the unchanged surface: `--> fix:` present, entity
names present, no `{` anywhere (no JSON leak), exit 1. The wiring test
asserts the registered subcommand's identity AND that `--json` is a flag
(JSON output), not an option (JSON input) — the exact #778-vs-output
conflict this bug exists to resolve. No test asserts a double or an
internal; every assertion is on the observable CLI/capability surface.

## Would they catch a bug? (rubric Q3 — deliberate mutants)

No mutation tool is wired in the repo's CI profile (same as spec 0974's
audit), so deliberate mutants on the changed logic, each run for real and
reverted with a re-green +11 afterwards:

| mutant | mutation | caught by | run |
|---|---|---|---|
| M1 | envelope `verdict` hardcoded to `pass` | B2 negative envelope test | `+10 -1` (`Expected: 'fail' / Actual: 'pass'`) → CAUGHT |
| M2 | exit code forced to 0 | B2/B3/B4 exit-code expectations | `+8 -3` → CAUGHT |
| M3 | crash fix reverted (`<String>{}` → `const {}`) | B6 regression test | `+10 -1` (`Unsupported operation: Cannot change an unmodifiable set`) → CAUGHT |
| M4 | `member` key dropped from finding JSON | B2/B3 exact-key assertions | `+9 -2` → CAUGHT |

4/4 caught, 0 survived. M3 is the load-bearing one: it proves the
regression test kills the exact crash that made the gate unusable on
every real project.

## Is every requirement covered? (rubric Q4)

Issue #1108 acceptance criteria plus orders:

| criterion / order | coverage | verdict |
|---|---|---|
| AC-1: `zfa di verify Product --json` emits the envelope; test asserts exact schema | B1 (+ E2E CLI run on a real `pub get` project: single-line `zuraffa.verdict.v1`, exit 0) | PROVED |
| AC-2: existing `--> fix:` output unchanged when `--json` absent | B4 (+ E2E: prose verdict + `--> fix:` lines, exit 1; text path byte-compatible with the CapabilityCommand surface: `✅ <msg>` / `❌ Failed: <msg>`) | PROVED |
| AC-3: all existing di_verify_test.dart tests still pass | 5/5 pre-existing #974 tests green before AND after (`+11` total) | PROVED |
| Order: envelope is the canonical #1104 shape — no ad-hoc keys | B1 asserts the exact 8-key set; B2/B3 assert exact finding keys | PROVED |
| Order: do not change verify semantics | verification lives in DiVerifyCapability (untouched check logic); additive `member` JSON key only; crash fix restores intended resolver behavior (a crash is not a semantic) | PROVED |
| Order 4: openwiki/cli.md `--json` row | di row in the plugin command table now documents the gate + envelope (#1104 sweep caveat: row added surgically to the existing table; the full sweep is issue #1104's own scope) | DONE |

Constraints check: failing-first tests (above); canonical envelope only
(no ad-hoc shapes); semantics unchanged (single source of truth in the
capability; exit taxonomy 0/1 preserved).

## Are the tests worth keeping? (rubric Q5)

Deterministic (temp-dir fixtures, injected projectRoot, hermetic
exitCode reset, no network), fast (the whole di_verify_test.dart file
runs in ~1s), consistent with the suite they join (they reuse the #974
fixture helpers and the provider-verify test's runZoned capture
pattern), and refactoring-insensitive (assertions on the envelope
contract, not on internals). The CLI-level tests construct the same
command class production registers (wiring pinned by B5), so they
cannot drift from the real surface silently.

## Honest failures (all pre-existing at base — none introduced here)

The chunked fast-tier run reported 2 failing chunks out of 82 (3222
test-passes / 3 test-failures / 4 chunks with no fast-tier tests):

| chunk | failure | pre-existing proof |
|---|---|---|
| test/plugins/cache | 2 failures: `cache_adapter_receipt_test.dart` expects receipt command `'cache-adapter'`, actual `'cache adapter'` | Reproduces with this branch's changes STASHED (base 512a8189): `00:33 +4 -2: Some tests failed`. Unrelated subsystem (cache receipts); untouched by this diff |
| test/plugins/state | 1 flake: `state_snapshot_test.dart` SC-3 golden byte-compare under within-chunk parallelism | Fails twice in a row at base with this branch stashed; also passes standalone (at base and with the branch) — pre-existing flake in the #1096 shared-state class, unrelated subsystem |

Out of scope for a minimal #1108 fix; reported so the fleet has the
breadcrumbs.

## Real CLI smoke (acceptance invocation, fresh scratch project)

```text
$ dart run bin/zfa.dart di verify Product --json      # clean tree
{"schema":"zuraffa.verdict.v1","command":"di verify","verdict":"pass","exit_class":"ok","subject":{"kind":"di","entity":"Product"},"findings":[],"drifts":[],"details":{"danglingClasses":[],"deadImports":[]}}
exit: 0

$ dart run bin/zfa.dart di verify Product --json      # dangling tree
{... "verdict":"fail","exit_class":"fail", "findings":[2 × {kind:"dangling binding", member: MissingUseCase|MissingRepository, fix: clean remediation}], "details":{"danglingClasses":["MissingUseCase","MissingRepository"],"deadImports":[]}}
exit: 1

$ dart run bin/zfa.dart di verify Product             # text mode, unchanged
❌ Failed: di verify: 2 finding(s) across 1 registration file(s)
lib/src/di/broken_di.dart: getIt<MissingUseCase> in ... binds a class that does not exist on disk
  --> fix: define MissingUseCase in lib/src/domain/usecases/<domain>/missing_usecase.dart and import it, or remove the registration
lib/src/di/broken_di.dart: getIt<MissingRepository> in ... binds a class that does not exist on disk
  --> fix: define MissingRepository in lib/src/data/repositories/missing_repository.dart and import it, or remove the registration
exit: 1
```

The positive-path smoke doubles as the crash-fix proof end-to-end: the
scratch project has a real `.dart_tool/package_config.json` and its DI
file imports `package:get_it/get_it.dart`, so the run traverses the
previously-crashing `_PackageResolver.provides` path and now verifies
green.

## Final gate (this session, real runs)

```text
dart test test/plugins/di/di_verify_test.dart  -> 00:00 +11: All tests passed!
dart analyze                                   -> 333 issues found (= base 333, zero new)
dart format --set-exit-if-changed --output=none. -> exit 0 (no remaining formatting diffs)
tools/run_tests_chunked.sh (slice runner, same semantics) -> 76/82 PASS, 4 SKIP, 2 FAIL (pre-existing, above)
```
