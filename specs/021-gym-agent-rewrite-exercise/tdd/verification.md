# TDD Verification: GYM Exercise — Agent Rewrite of a Dart Package Using Only zfa

Audit report for `/speckit.tdd.verify` — spec 021, branch `021-gym-agent-rewrite-exercise`.

**Verdict: PASS.** Every acceptance criterion is backed by a green run through the exercise's real entry point, every behavior on the test list is `DONE` with named evidence, red evidence exists for each substantive cycle (cycles 1, 3, 4; cycles 2 and 5 are born-green with documented justification and teeth), and the repo suite is unregressed (the feature touches no `lib/` or `test/` file).

## 1. Suite status

| Command | Result |
|---------|--------|
| `dart run .gym/exercise-agent-rewrite-zfa-only.dart` (the graded surface) | **EXERCISE PASSED — exit 0** (after 4 red-green cycles; see `cycle-log.md`) |
| `dart run .gym/exercise-agent-rewrite-zfa-only.dart` (repeat, clean sandbox) | exit 0, file structure byte-identical across runs (`ls -R` diff empty) |
| `dart run .gym/exercise-generate-feature.dart` (existing-exercise regression) | **EXERCISE PASSED — exit 0** (same as master baseline) |
| `dart analyze` | 111 issues / 23 errors — **byte-identical to the master baseline** (`diff` of sorted output empty); all pre-existing in the standalone `zikzak_session` package (now published on pub.dev) + `examples/mcp_demo/`; `.gym/**` is excluded from analysis by `analysis_options.yaml` |
| `dart test` (fast tier, run directory-by-directory — a single full invocation exceeds session limits and produced an 8.5 GB kernel artifact) | **2,441 passed, 0 failed, 1 skipped** across every default-suite directory: agent 144, app_update 6, biometrics 7, cli 139, clipboard 6, commands 224, config 10, core 572 (+1 skip), dda 35, device 6, domain 18, graphql 128, i18n 11, logging 6, mcp 71, migration 20, plugins: api 30, app_shell 75, benchmark 106, datasource 5, di 6, gym 15, method_append 6, mock 37, module 2, provider 4, repository 7, route 35, service 8, shadcn 2, sqlite 8, state 2, strategy 26, sync 31, tdd 26, tui 66, usecase 17, xray 128, test_builder 5, toggle 3, mcp files individually 103, regression 78, secure_storage 11, session 20, share 5, state 99, utils 72 |

Suite baseline at planning time: existing exercise green; this feature adds no `lib/`/`test/` files, so the suite outcome is master's by construction — and was re-run in full to confirm (counts above).

**Known pre-existing issue (not caused by this feature):** `test/plugins/mcp/mcp_server_plugin_test.dart` hangs when run as a full file (SSE-server lifecycle across tests in this sandbox). Verified identical-on-master behavior via spec 038's clean-worktree check; individual tests in the file pass (e.g. `--name "autoStartSsePort"` → `+1: All tests passed!`). All other mcp test files pass individually (103 tests). Flagged, not fixed — out of scope.

## 2. Acceptance criteria — proven or not

| SC | Claim | Status | Evidence |
|----|-------|--------|----------|
| SC-001 | Compatible package → zfa-only rewrite output compiles + matches canonical v5 layout for all entities | **PROVEN** | Leg A of the exercise: `zfa doctor` markers confirmed → `zfa entity create -n Note --field …` ×2 (Note, Tag) → `zfa make <Name> datasource repository usecase` ×2 → `zfa build` → `dart analyze: no errors` (compilation, FR-004) → verification block asserts per-entity `lib/src/domain/entities/<snake>/<snake>.dart` + `@Zorphy` + every declared field getter + `.zorphy.dart`/`.g.dart` parts + repository/datasource/usecase files. Cycle-3 red proves the verification has teeth (failed with the named missing `note.dart` while invocations were disabled). |
| SC-002 | Non-compatible package → stop before rewrite + structured report, exit 0 | **PROVEN** | Leg B: `zfa doctor` surfaces both not-found markers → the protocol writes `NOT-ZURAFFA-COMPATIBLE.md` (Package / Verdict / Why-with-doctor-evidence / What-would-make-it-compatible sections, all asserted) and structurally invokes no rewrite command (leg B contains no `_runZfa` call) → lib/ pristine + no `lib/src/domain/entities/` tree asserted → overall exercise exit 0 (correct behavior graded PASS per FR-007). |
| SC-003 | Runnable end-to-end headless by the miki runner, deterministic grade | **PROVEN** | The exercise is a single self-grading script wired as `verifyCommand: dart run .gym/exercise-agent-rewrite-zfa-only.dart` with `evaluate: exit 0 => pass; exit !=0 => fail` — the exact contract the runner consumes (mirrors the existing generate-feature entry). Two consecutive clean-sandbox runs: exit 0 both, identical file structure. No manual intervention anywhere in the loop. |
| SC-004 | Discoverable in the GYM registry with a clear brief | **PROVEN** | `.gym/gym.yaml` parses (`yaml.safe_load`) and lists exercises `['generate-feature', 'agent-rewrite-zfa-only']`; the entry carries a full brief (what it trains: zfa-only rewrite + stop-and-report, referencing #478/#477), setup notes, verifyCommand, and the evaluate rule, in the same shape as the existing entry. |

## 3. Behavior coverage

All 14 unit behaviors (U1–U14) and 4 acceptance behaviors (A1–A4) are `DONE` with named evidence in `tdd/test-list.md`. Red evidence per cycle is in `tdd/cycle-log.md`:

- Cycle 1 (U1–U3): assertion-red — fixture staging failed with the named missing fixture before the fixtures were created.
- Cycle 2 (U4–U5): born-green, justified — `zfa doctor` is a pre-existing capability (grounded in plan.md research on master); teeth provided by cross-coupled mutual-exclusivity assertions (leg A requires compatible markers AND absence of not-found markers; leg B the inverse), so pointing either at the wrong fixture fails.
- Cycle 3 (U6–U9): assertion-red — with the protocol invocations disabled, the verification failed with the named missing `lib/src/domain/entities/note/note.dart`; green after the zfa-only invocations were wired. This red doubles as U9's failure-shape proof (named missing artifact, no silent partial pass).
- Cycle 4 (U10–U12): assertion-red — report missing before `_stopAndReport()` existed; green after. U12's both-ways evidence: exit 0 on passing runs, exit 1 + `EXERCISE FAILED` on every red run in the log.
- Cycle 5 (U13–U14): born-green (declarative registry edit) — validated by YAML parse, registry shape check, determinism runs, and the generate-feature regression run (exit 0).

FR traceability: FR-001 (U13, registry entry), FR-002 (U4/U5 + ordering: detection precedes every rewrite command), FR-003 (U3 + fixtures embedded under `.gym/fixtures/`, fixed + versioned), FR-004 (U6–U9), FR-005 (U10/U11 + structural no-misfire), FR-006 (U2 + `git status` clean of tracked modifications after full runs), FR-007 (U12), FR-008 (U6–U8 via the `_runZfa` choke-point; fixture copy + `dart pub get` confined to setup). Spec edge cases: setup-failure → `_fail('SETUP ERROR: …')` distinct from graded failure; partial output → named-artifact failures; empty package → manifest-driven entity creation orders entities before architecture; zfa missing → named setup error at start; #477-class targets → stop-and-report leg.

## 4. Mutation sampling (no mutation tool wired — deliberate mutants per profile)

| Mutant | Expected kill | Result |
|--------|---------------|--------|
| M1 protocol invocations disabled (`if (false)` wrap of steps 2–4) | U6–U9 | **Killed** — `LEG A verify: canonical v5 entity file missing for Note` exit 1 (cycle-3 red run) |
| M2 report writer removed | U10 | **Killed** — `LEG B verify: structured report missing` exit 1 (cycle-4 red run) |
| M3 fixtures deleted | U3 | **Killed** — `Required fixture missing: …/sample-crud-package/pubspec.yaml` exit 1 (cycle-1 red run) |
| M4 detection pointed at the wrong fixture (swap verdict assertions) | U4/U5 | **Killed by construction** — leg A asserts `!output.contains('Zuraffa package not found')` and leg B asserts `compatible == false`, so swapped fixtures fail both legs |

## 5. Honest gaps and flagged pre-existing issues

1. **The exercise is protocol-executing, not operator-adjudicating.** The script performs the trained protocol itself and grades the artifacts (the repo's established exercise pattern — see `exercise-generate-feature.dart`). An operator's *own* zfa-only rewrite would be graded by the same assertions if run against the staged sandbox; the miki runner's `.submitted`-marker flow supports that workflow, but this PR does not add operator-session tooling. The brief in `gym.yaml` documents the protocol the operator is expected to follow.
2. **`zfa doctor`'s exit code is 0 for both compatible and non-compatible packages** — detection parses output markers, not exit codes. This is master's behavior; the exercise asserts the markers explicitly and fails loudly if doctor's wording ever drifts (marker assertions double as a doctor-output contract test).
3. **Fixture pubspecs pin `zuraffa` via the `__ZURAFFA_ROOT__` placeholder** resolved at setup to this checkout — deterministic and offline-friendly, but it means the sandbox compiles against the local tree rather than a published zuraffa version. This is intentional (the exercise validates THIS repo's zfa); a pub.dev-pinned variant would drift.
4. **`test/plugins/mcp/mcp_server_plugin_test.dart` full-file hang** — pre-existing on master (see §1), re-confirmed by individual-test pass. Not addressed: out of scope for this feature (no `lib/`/`test/` changes allowed).
5. **Cycle 2 and cycle 5 have no red evidence** — born-green cycles with documented justification and compensating teeth (mutual-exclusivity assertions; parse + regression + determinism runs). Recorded rather than hidden.
