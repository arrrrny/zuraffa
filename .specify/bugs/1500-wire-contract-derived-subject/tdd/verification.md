---
feature: 1500-wire-contract-derived-subject
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/1500-wire-contract-derived-subject
behaviors: 12
proven: 12
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: n/a # no mutation tool on this agent; behavior-level assertions assert exact rendered signatures/bodies
mutants_survived: 0
suite: bug-1500 12/12 + wire pins 15/15 in one run (00:09 +27: All tests passed!); chunked fast tier 503 (tdd/commands) + 855 (tdd/services) + 472 (tdd root) = 1,830 passed / 0 failed; scenarios chunk fully slow-tagged (excluded by dart_test.yaml); CI-scope dart analyze on changed files exit 0 (No issues found); dart format --set-exit-if-changed exit 0
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
2. **GREEN is real**: the same suite post-fix reports `+27: All tests
   passed!` — U-1500a (declared `Task` + `TaskMockData.sampleTask` +
   both imports + declared params, no `return null as`), U-1500b
   (misfire-stop naming `zfa mock create --name Task`, subject untouched),
   U-1500c (`List<Task>` → `sampleList`), U-1500d (`Task?` →
   `sampleTask`), U-1500e/f/g (scalar literals, no mock), U-1500h (legacy
   byte-compat), U-1500i/j (comment lines never match; block-body shapes
   still refused), U-1500k (provenance-header fallback), U-1500l
   (declared beats description inference).
3. **No collateral damage**: the pre-existing wire pins
   (`wire_command_test.dart` U-W1–U-W7, U-829a/b, U-920a–e) pass
   unchanged; the chunked fast tier over the affected plugin surface
   (tdd/commands 503, tdd/services 855, tdd root 472) reports zero
   failures; the scenarios chunk is fully slow-tagged and correctly
   excluded by `dart_test.yaml`.
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
