---
feature: 1500-wire-contract-derived-subject
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/1500-wire-contract-derived-subject
behaviors: 21
proven: 21
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 8
criteria_covered: 8
mutation_score: n/a # no mutation tool on this agent; behavior-level assertions assert exact rendered signatures/bodies, and three behaviors assert `dart analyze` exit 0 over the wired subject
mutants_survived: 0
suite: bug-1500 21/21 + wire pins 15/15 in one run (05:16 +36: All tests passed!); wire json/verdict pins 43 passed; generation_planner 31 passed; scenarios chunk fully slow-tagged (excluded by dart_test.yaml); CI-scope dart analyze on changed files exit 0 (No issues found); dart format --set-exit-if-changed lib test exit 0 (0 changed). All figures re-captured on macOS / dart 3.13.2 for this fix round — the earlier Linux `+27` line did not reproduce on macOS; see the review round.
---

# TDD Verification: wire accepts contract-derived stubs; binds entity returns to MockData (#1500)

**Verdict: PASS.** `zfa tdd wire` now accepts every stub shape
SubjectWriter emits, resolves the declared return through the shared
declared-intent machinery (never the degraded `Object?`), preserves the
declared parameters, binds entity/generic/nullable returns to the
generated `<E>MockData` samples with the import, and misfire-stops naming
`zfa mock create --name <E>` when the pipeline's mock step was skipped —
with the legacy no-arg path byte-compatible.

## What the run proved (fresh, this branch)

1. **RED was honest** (`tdd/cycle-log.md`, `red-evidence.md`): 8/12 new
   behaviors failed pre-fix for the issue's exact signature —
   `outcome=runner-error`, "unrecognized shape", exit 1 — while the 4
   regression pins passed pre-fix.
2. **GREEN is real**: the suite post-fix reports `+36: All tests passed!`
   on macOS — U-1500a (declared `Task` + `TaskMockData.sampleTask` +
   both imports + declared params, no `return null as`), U-1500b
   (misfire-stop naming `zfa mock create --name Task`, subject untouched),
   U-1500c (`List<Task>` → `sampleList`), U-1500d (`Task?` →
   `sampleTask`), U-1500e/f/g (scalar literals, no mock), U-1500h (legacy
   byte-compat), U-1500i/j (comment lines never match; block-body shapes
   still refused), U-1500k (provenance-header fallback), U-1500l
   (declared beats description inference), and the pull/1516 review-round
   behaviors U-1500m/n/u/o/p/q/r/s/t.
3. **No collateral damage**: the pre-existing wire pins
   (`wire_command_test.dart` U-W1–U-W7, U-829a/b, U-920a–e) pass
   unchanged; the wire json/verdict pins (43) and
   `generation_planner_test.dart` (31) pass; the scenarios chunk is fully
   slow-tagged and correctly excluded by `dart_test.yaml`. (`make_command_test.dart`
   is likewise fully slow-tagged, so it is outside the fast tier.)
4. **Static hygiene**: `dart analyze` on every changed Dart file exits 0
   with no issues; `dart format --set-exit-if-changed` reports 0 changed.
5. **Constraint compliance**: `git diff` touches exactly
   `lib/src/plugins/tdd/commands/wire_command.dart` (plus the new test and
   these artifacts); gen, SubjectWriter, and the state machine are
   untouched.

## Criteria coverage

| Criterion | Evidence |
| --- | --- |
| 1. `_stubSignature` accepts what SubjectWriter emits | U-1500a–f, U-1500k, U-1500l (red→green transition on each) |
| 2. declared return used — never degraded `Object?` | U-1500a/d (`Task`/`Task?` signatures, `isNot(contains('Object? subject_u2'))`), U-1500l |
| 3. entity returns bind to `<E>MockData.sample<E>`/`.sampleList` + import | U-1500a/c/d assertions on body + `package:` import |
| 4. missing mock-data → misfire-stop naming `zfa mock create --name <E>` | U-1500b (exit 1, subject untouched) |
| 5. wired signature keeps declared parameters | U-1500a (`Task subject_u2(String title) {`, `isNot(contains('subject_u2() {'))`) |

## Review round — pull/1516 (findings applied, re-verified)

The original `+27` figure was a Linux capture; on macOS the same command
reported `+26 -1` because U-W3 hit the symlinked-temp-root defect below.
Both are fixed and the suite now reports `+36: All tests passed!` on macOS
(dart 3.13.2).

| # | Finding | Resolution | Evidence |
| - | ------- | ---------- | -------- |
| 1 | 🟠 mock binding keyed to the declared entity while the plan creates mock data for `--entity` → permanent dead-end | the hard-stop now applies only when the declared base IS `--entity`; a mismatch binds the declared entity's own mock data when present, else degrades to the stub's renderable shape | U-1500m (own mock bound), U-1500n (absent mock → no dead-end, exit 0), U-1500u (not a generated entity) |
| 2 | 🟠 the declared return's class was never imported → the wired subject did not compile | `locateEntityFile` + `package:` import for a declared base different from `--entity` | U-1500m (`dart analyze` exit 0), U-1500u |
| 3 | 🟡 `num`/`DateTime` had no literal → `return null as <T>;` | real literals (`0`, `DateTime.now()`) | U-1500s |
| 4 | 🟡 new refusal/fallback branches untested | tests added for the declaration refusal, `Set`/`Iterable` accessors, and the plausibility-gate rejection | U-1500o/p/q/r/t |
| 5 | 🟡 fixture hand-copied `SubjectWriter`; nothing compiled the output | fixture renders via `SubjectWriter.render`; three behaviors assert `dart analyze` exit 0 | U-1500m/n/u |
| 🔵 | `deriveSubjectSignature` computed twice; nullable collections unbound; no staleness note | hoisted; `List<Task>?` binds; documented | U-1500q |
| ⚠️ | the stated `+27` evidence did not reproduce on macOS (U-W3) | missing-subject path canonicalizes through its nearest existing ancestor | U-W3 green on macOS |

**Note on criterion 2:** the declared return is still never *degraded* in
the pipeline's own path. The one exception is deliberate and new: when the
declared base differs from `--entity` AND the pipeline did not generate
mock data for it, wire keeps the stub's renderable shape rather than emit
`return null as <Declared>;` — which `dart analyze` flags as
`cast_from_null_always_fails`, exactly the crashing-cast class this change
removes.
