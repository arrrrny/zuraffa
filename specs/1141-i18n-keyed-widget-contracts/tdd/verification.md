# TDD Verification — 1141-i18n-keyed-widget-contracts (issue #1141)

**Generated:** 2026-09-06, FRESH from this session's actual runs (FR-019
discipline — never a stale copy). Written through the `/speckit.tdd.verify`
audit: engine detection returned `ZFA_MISSING`-equivalent (no registered
behavior artifacts for this feature — the spec's behaviors are the four
hand-written suites below), so the LLM-guided audit path applies per
`.specify/extensions/tdd/commands/speckit.tdd.verify.md`.

## Verdict: PASS (with recorded notes)

Every behavior landed test-first with captured red evidence, 23 new tests
green across 4 suites, the full fast suite passes chunked with NO new
failures, `dart analyze` reports ZERO new findings vs master, and the
issue's three acceptance criteria were PROVEN with real end-to-end runs
on a scratch Flutter host (not projections). Mutation audit: 8/8 targeted
mutants killed.

## 1. Test-first evidence (cycle-log)

The four suites were written and run BEFORE any implementation change
(`specs/1141-i18n-keyed-widget-contracts/tdd/cycle-log.md` carries the
command, exit code, and output excerpt of each red run):

| Suite | RED (pre-implementation) | GREEN (commit 76cdc1c2) |
| --- | --- | --- |
| bug_1141_ledger_wiring_test.dart | 6/6 failing (assertionFailure: no `tdd/ui-ledger.md`, no stdout line) | 7/7 passed |
| bug_1141_view_audit_test.dart | compile red (`Undefined name 'UiViewAudit'`, `Member not found: 'UiLedgerBuilder.quotedUserFacingStrings'`) | 9/9 passed |
| build_command_slang_stage_test.dart | compile red (`Method not found: 'SlangBuildStage'`) | 4/4 passed |
| bug_1141_login_ui_regeneration_test.dart | 3/3 failing (ledger missing + the pre-existing view no-op on the #959 inert stub) | 3/3 passed |

The keyed emission itself (`Text(t.auth.signIn)`, the slang test shell,
the scaffold merge) was ALREADY green on master via #965 — the honest
baseline, recorded as such in the cycle-log (same discipline as 0965's
zero-drift cases).

## 2. Root causes the RED phase surfaced (both pre-existing, both fixed)

1. **The view step could not rewrite the #959 inert stub.**
   `zfa tdd gen` emits `Widget <n>() => const SizedBox.shrink();` since
   issue #959, but `zfa tdd view`'s stub regex only matched the older
   throwing shape — a freshly generated subject no-op'd as "already
   implemented", so the regeneration loop (gen → view) was broken
   end-to-end. Fix: the view step rewrites either red shape.
2. **The #919 layer-contract round trip lost the contract.** Plan
   rendered layer-contract methods UNBACKTICKED, while
   `TestListReader.readLayerContracts` extracts backticked tokens only —
   components AND `key:` tokens silently vanished on the plan →
   test-list leg. Fix: methods render backticked in both plan paths
   (legacy + lane split), matching the reader contract the 919 reader
   test pins.

## 3. Test-smell rubric (applied to the 4 new suites)

- **No unconditional placeholders**: every test asserts a content
  contract (`contains`/`isNot`/byte-equality on generated artifacts);
  no `expect(true, isFalse)`, no vacuous finders.
- **No sleeps / no wall-clock dependence**: content-level and
  deterministic-CLI drives through the house `CliRunner.runCapturing` +
  temp fixtures; no polling.
- **Determinism proven**: the ledger artifact and the audit are pure
  functions of declared inputs; the A2 copy-edit test proves the keyed
  assertion lines byte-identical across a fixture anchor edit.
- **Zero-drift guarded**: U5 (no declared keys → scenario-literal view
  keeps exit 0, byte-identical output), U7 (no i18n sources → the build
  stage prints NOTHING and invokes nothing), the 0965 suites all green
  unchanged (53/53 in this session's runs).
- **Errors-are-an-API asserted**: the untraced refusal happens BEFORE
  any write (subject bytes unchanged, no lib/i18n created), each
  violation carries a `--> fix:` line; the plan's i18n-contract refusal
  (malformed `key:` token) exits 2 with `exitClass=i18n-contract`.
- **Suite isolation**: temp fixtures per test, `tearDown` disposal,
  `exitCode` reset (house convention).

## 4. Mutation results (targeted audit on the NEW logic)

Harness: `/home/z/my-project/scripts/mutation_audit_1141.sh` (exact-string
mutation, run, `git checkout` revert — run AFTER the green commit so the
revert is sound; see the incident note in §7). Each mutant must be KILLED
by a scoped suite:

| Mutant | File | Mutation | Result |
| --- | --- | --- | --- |
| M1 | `ui_ledger_projection.dart` | audit's hardcoded-key check bypassed (`if (true) continue`) | KILLED (1 test) |
| M2 | `ui_ledger_builder.dart` | detector drops the key-anchor trace path | KILLED (1 test) |
| M3 | `view_command.dart` | the audit gate disabled (`if (false && !audit.isClean)`) | KILLED (1 test) |
| M4 | `plan_command.dart` | ledger write skipped (`if (true) return {}`) | KILLED (1 test) |
| M5 | `build_slang_stage.dart` | stage always decides `skipped` | KILLED (3 tests) |
| M6 | `view_command.dart` | inert-stub match dropped (view no-ops fresh stubs) | KILLED (3 tests) |
| M7 | `ui_ledger_projection.dart` | anchors feed text rows (key rows lose their prover tracing) | KILLED (1 test) |
| M8 | `plan_command.dart` | the #919 backtick round-trip fix reverted | KILLED (1 test) |

Survivors: 0. Every revert was re-verified green.

## 5. Acceptance-criteria coverage (the issue's verification list)

The issue's three criteria were PROVEN with REAL end-to-end runs on a
scratch Flutter host (`flutter create`, `slang` + `slang_flutter` +
`build_runner` wired, `zfa` compiled from this branch):

### Criterion 1 — 004-login-ui regenerated: zero hardcoded user-facing strings

```
$ zfa tdd plan 004-login-ui --project .      → exit 0
   zfa tdd plan: wrote .../tdd/ui-ledger.md (6 row(s), 4 key row(s)) — the UI surface ledger (issue #1141)
$ zfa tdd gen W1 --project . --widget-shell materialapp → exit 0
$ zfa tdd view W1 --project .                → exit 0
   i18n: 1 keyed surface(s) (t.auth.signIn)
   i18n audit: clean — 6 surface(s) declared, 0 violation(s) (issue #1141)
   scaffold: lib/i18n/strings.i18n.json (missing keys scaffolded)
```
The regenerated `lib/tdd/004-login-ui/w1_subject.dart` contains exactly
ONE Text call — `Text(t.auth.signIn),` — and zero quoted user-facing
strings (grep + `UiLedgerBuilder.quotedUserFacingStrings` both empty).
`lib/i18n/strings.i18n.json` carries all four declared keys
(auth.signIn/email/password/sessionStarted). The ledger:
`t.<key>` per row (4 key rows), the `deal_list` route row, and the
`ShadInput` affordance row.

### Criterion 2 — EN copy edit does NOT break generated tests (REAL run)

```
$ flutter test test/tdd/004-login-ui/w1_test.dart   → 00:00 +1: All tests passed!
$ sed -i 's/"signIn": "Sign in"/"signIn": "Log In"/' lib/i18n/strings.i18n.json
$ dart run slang                                    → Translations generated successfully
$ flutter test test/tdd/004-login-ui/w1_test.dart   → 00:00 +1: All tests passed!
```
The EN copy edit survived the full codegen + test cycle green — the
generated test asserts `find.text(t.auth.signIn)`, never the EN string
(the A2 suite additionally proves the assertion line byte-identical
under the edit, by construction).

### Criterion 3 — zfa build succeeds after generation without manual i18n edits (REAL run)

```
$ zfa build
🌐 slang: 1 translation source(s) (lib/i18n/strings.i18n.json) — running dart run slang (issues #834/#1141)
   ✅ slang codegen completed
🔨 Running build_runner build...      → Built with build_runner/aot; wrote 0 outputs.
✅ Build completed successfully
🔎 dart analyze on lib/...           → No issues found!
   ✅ dart analyze: no errors        → build exit=0
```
The slang stage ran BEFORE build_runner (issue #834's design), the
generated view's `package:login_host/i18n/strings.g.dart` import
resolved, and the post-build analyze gate passed on the generated view.
Host toolchain setup (adding slang/slang_flutter deps) is host
bootstrap, not an i18n edit; the stage refuses honestly (fix line,
non-zero exit) when sources exist but the toolchain is unresolvable.

| Issue criterion | Proving tests / runs |
| --- | --- |
| 004-login-ui regenerated, zero hardcoded strings | bug_1141_login_ui_regeneration_test.dart (A1, U9) + the real drive above |
| EN copy edit does not break generated tests | same suite (A2, byte-identical keyed assertions) + the real flutter-test cycle above |
| zfa build succeeds after generation | build_command_slang_stage_test.dart (U6-U8) + the real zfa build above |
| Ledger traces t.<key> per row | bug_1141_ledger_wiring_test.dart (U1 ×5, U2) |
| Hardcoded strings are untraced-surface violations | bug_1141_view_audit_test.dart (U3-U5 ×9) |

## 6. Verification run (this session, final state = commit 76cdc1c2)

```
dart analyze                       # 134 issues on this branch == 134 on
                                   # master (stashed baseline) — ZERO new
dart format .                      # 2346 files, 0 changed; git diff empty
tools/run_tests_chunked.sh         # 84/91 chunks PASS (3487 tests), 7
                                   # chunks skip-class (all their tests are
                                   # slow/flutter-tagged: benchmark,
                                   # core/dependencies, core/proof,
                                   # integration, tdd/scenarios,
                                   # 077-make-engine-preset,
                                   # bug-tdd-run-baseline-timeout) — the
                                   # same skip class 1138 recorded
dart test test/plugins/tdd/commands/   # 279 passed (incl. the 0965 + 1141 suites)
dart test test/plugins/tdd/services/   # 685 passed
dart test test/commands/               # 253 passed (incl. the slang stage suite)
dart test test/tdd/                    # 125 passed
```

Note (pre-existing, not this branch's): the four folders above carry
more root-level test files than the chunker's 40-file threshold, so the
chunked runner recurses into their subfolders only — they were run
explicitly (CI runs `dart test test --exclude-tags flutter` in one
invocation, which covers them; the chunker is a small-disk-agent tool).

## 7. Incident note (recorded for institutional memory)

The first mutation-audit pass ran BEFORE the green commit, and its
`git checkout` revert — sound in 0965's committed workflow — restored
the three TRACKED implementation files to master state (the untracked
new files kept their live mutants). The damage was detected immediately
(the suites re-failed), the files were re-applied from the recorded
edits, verified 23/23 green, and the implementation was COMMITTED before
the audit was re-run (killed=7 automated + M6 run manually after dart
format changed the anchor string). Harness lesson now encoded in the
script's header: "Run ONLY after the branch is committed."

## 8. Remediation tasks

None — the gate passed. Follow-ups OUT of this spec's scope:
(1) the chunker's root-file gap for >40-file folders (pre-existing; CI's
single-invocation `dart test` covers them); (2) wiring ledger state
recompute into `zfa tdd status`/coverage reads (075's remaining scope).
