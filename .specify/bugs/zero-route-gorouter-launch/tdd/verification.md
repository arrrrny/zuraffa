---
feature: zero-route-gorouter-launch (bug #1673)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/zero-route-gorouter-launch (working tree)
behaviors: 8
proven: 8
engine_certified: 5
hand_proven: 3
likely: 0
no_test: 0
high_smells: 0
criteria_total: 8
criteria_covered: 8
mutation_score: 100 # deliberate-mutant sampling, 2/2 killed (M1 after one assertion-strengthening remediation), scope: changed files
mutants_survived: 0
suite: blast-area chunks green (app_shell 89, cli+writers 71, tdd feature 72, commands 384, cli 264); dart analyze clean; dart format clean; chunked full tier: last chunk green, non-blast-area chunk failure under parallel load (see notes)
audit_mode: manual (fallback) — mechanical `zfa tdd verify` BLOCKED by pre-existing repo-wide proof-store drift, zero findings in this bug's chain

# TDD Verification: day-zero zero-route GoRouter (issue #1673)

**Verdict: PASS_WITH_GAPS.** All 8 acceptance criteria are covered by passing
tests with red-first evidence; the deliberate-mutant sample (2/2 killed) found
and fixed one genuinely weak assertion. The gaps are process-level, not
evidential, and each is disclosed below with its root cause.

## Why the mechanical audit is BLOCKED (not this fix's doing)

`zfa tdd verify` runs a store-wide proof preflight (`zfa proof check`, issue
#807 chain). The store carries 103 live receipts with 65 findings — ALL in six
OTHER features/bugs (`078-skin-contract-schema`, `079-skin-contract-binding`,
`specs/1653-mutation-test-opt-in-pre-resolve`, `zfa-setup-app-name`,
`bug-tdd-run-baseline-timeout`, `077-make-engine-preset`): hand-edited or
reformatted artifacts whose gen receipts predate the edits, and dead temp
sandboxes (31 of the latter were pruned via `zfa proof prune --apply`,
issue #1378). **This bug's artifacts have ZERO drift** (`zfa proof check |
grep -c zero-route-gorouter-launch` → 0). Repairing foreign drift would require
re-running gen over other features' hand-implemented subjects, clobbering their
designed hand steps — not done.

## Test-first evidence

| Behavior | Class | Evidence |
| ------------------------------------------------------------------------ | ---------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| A3: skin-audit router carries errorBuilder + fallback alongside observer | PROVEN | `verify-red` certified RED (assertion class: pre-fix emission lacked `errorBuilder` — live red captured in cycle-log); fix applied; born-green certified (skip transition, issue #694); re-certified twice after format/assertion-strengthening (issue #1162) |
| A4: runtime empty-check preserves a real route table | PROVEN | `verify-red` certified RED (guard, assertion class); hand-stepped real assertion; born-green certified |
| A5: fallback runtime-side in app_router.dart; index regenerator never touches it | PROVEN | same engine path as A4 |
| A6: pure-Dart smoke flavor stays router-free | PROVEN | same engine path as A4 |
| A8: golden surface asserts the new emission | PROVEN | same engine path as A4 |
| A1: bare variant installs errorBuilder + fallback | PROVEN (hand) | widget lane REFUSED to scaffold (issue #938: pure-Dart repo cannot declare zuraffa_ui; no gen receipts → make refuses born-green). Hand-written in the acceptance shape; green in suite; disclosure in fix.md |
| A2: day-zero `/` resolves via placeholder, not GoException | PROVEN (hand) | same refusal path as A1; emission-level proof (fallback route claims `/` + errorBuilder) plus the live `flutter run` proof recorded on the issue |
| A7: Flutter smoke test pumps shell, asserts `/` resolves | PROVEN (hand) | same refusal path as A1; asserts the EMITTED TEMPLATE (container check kept + `testWidgets` pump + `takeException` null). Live pump runs in the generated app (slow-tier `day_zero_smoke_gate_test`) |

## Deliberate-mutant sampling (changed files)

| Mutant | Applied change | Verdict |
| ------ | -------------- | ------- |
| M1 | remove both `'errorBuilder': _placeholderBuilderClosure()` args from `AppShellBuilder` emission | SURVIVED first pass — `contains('errorBuilder')` matched the emitted leading COMMENT (introduced with the fix). REMEDIATED: a1/a2/a3/a8 strengthened to `contains('errorBuilder: (context, state)')` (named-arg form, comment cannot match). Re-applied → 4 tests RED → KILLED |
| M2 | remove the `bootstrap routing (issue #1673)` group from `SmokeTestWriter` Flutter template | KILLED — a7 went RED (`testWidgets`/`pumpWidget`/`takeException` assertions all lost) |

Restoration verified after each mutant (byte-identical restore, full feature
dir green). M1's survival was the audit working as designed: the assertion is
now materially stronger.

## Test smells

- No vacuous guards remain in any feature test (the acceptance-guard marker was
  removed at each hand step per issue #1488; `--born-green` attestation gates
  enforced it).
- No sleeps, no order dependence, no true/name-only assertions; assertions pin
  emitted-code structure (named-arg form, conditional branches, imports).
- One smell noted and accepted: A5 reads `route_builder.dart` from the process
  working directory (documented in the subject; both `dart test` and the runner
  set it to the project root).

## Criteria coverage

AC-1→A1, AC-2→A2, AC-3→A3, AC-4→A4, AC-5→A5, AC-6→A6, AC-7→A7, AC-8→A8 —
8/8 covered, traced in `tdd/traceability.md`.

## Gaps

1. Mechanical `zfa tdd verify` gate blocked by foreign proof-store drift (see
   above) — the audit above is the skill's manual fallback.
2. A1/A2/A7 are hand-proven, not engine-certified (widget lane needs a Flutter
   host, issue #938).
3. The loop driver's refactor gate (full-suite re-proof) was satisfied
   manually — focused blast-area suites + chunked tier; see the GATE entry in
   `tdd/cycle-log.md` and fix.md Deviations (the #1333 economics follow-up).
4. This audit was written by the same session that wrote the tests.
