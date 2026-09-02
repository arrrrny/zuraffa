# Cycle Log — bug 874 (tdd doctor cross-feature adoption + migration)

Feature: tdd-doctor-cross-feature-adoption (GitHub issue #874, severity high)
Branch: fix/874-doctor-cross-feature-adoption-migration (base: e273fa43)

## Cycle: R-1 (red — the issue's trust violation, reproduced)

- behavior: doctor-prescribes-migrate-never-adopt
- kind: red
- classification: assertionFailure
- criterion: requirement 1 (cross-registry awareness) + 3 (owner in verdict)
- test: test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart
- command: `dart test test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart --preset=all`
- exit: 1
- at: 2026-09-03 (session)
- output (suite tally `+4 -7`; the repro test's verdict was the #840 `adopt`
  prescription):
```
doctor prescribes migrate (never adopt) for another feature's flat
artifacts — the issue repro [E]
  Expected: contains 'foreign-owned'
  Actual: '{"command":"doctor","feature":"004-dependency-injection",
  "verdict":"drift","prescription":"adopt","fix":"zfa tdd gen A3 --adopt
  --feature 004-dependency-injection", ...}'
```
- note: fixture = the issue's exact state — feature 001 completed on a
  pre-#827 binary (flat pair at test/tdd/a3_test.dart, OWNED by 001's
  registry), feature 004 on the post-#827 binary. `zfa tdd doctor
  004-dependency-injection` consulted ONLY 004's registry, declared 001's
  file "unowned" and prescribed adopting it — the trust violation. Six
  further reds in the same run: owned_by verdict field absent,
  relative-path records unresolved, multi-owner fix wrong, precedence
  wrong, gen --adopt registered the foreign file (`"verdict":"adopted"` —
  the literal corruption), plain gen lacked the foreign-owned verdict.
  Controls already green: unowned→adopt (#840), owner's own run healthy,
  gen-adopt-unowned, gen-prior-record refusal.

## Cycle: G-1 (green — cross-registry awareness + foreign-owned guardrail)

- behavior: foreign-owned classification in doctor + gen recovery path
- kind: green
- criterion: requirements 1, 2, 3
- test: same suite
- command: `dart test test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart --preset=all`
- exit: 0
- at: 2026-09-03 (session)
- output:
```
00:00 +11: All tests passed!
```
- note: `cross_feature_ownership.dart` maps every recorded artifact path
  across ALL specs/*/tdd/artifacts.json to its owner (normalized absolute
  form; absolute and project-relative recorded shapes resolve alike).
  Doctor partitions the legacy-layout scan: foreign-owned -> verdict
  `foreign-owned`, prescription `migrate`, fix `zfa tdd migrate-paths
  <owner>` (single owner) / `zfa tdd migrate-paths` (multiple), `owned_by`
  map in the verdict, drift lines name the owner, never `--adopt`;
  genuinely unowned keeps #840's adopt. Gen's recovery path refuses
  foreign-owned files in both the non-adopt conflict (verdict
  `foreign-owned`) and the adopt fallback (verdict `foreign-owned`,
  registry untouched, file bytes untouched — the house exitCode+return
  pattern keeps the JSON verdict the final stdout line).

## Cycle: V-1 (verify — full battery)

- behavior: no regressions outside the bug's scope
- kind: verification
- criterion: house verification gates
- command / result:
  - `dart analyze` -> 47 issues, all pre-existing repo infos (zero in the
    changed files: doctor_command.dart, gen_command.dart,
    cross_feature_ownership.dart, bug_874 test)
  - chunked fast tier (house runner semantics, 68 folders, kernel cache
    cleared per chunk, 4 range batches) -> all 68 OK (`fail=0`)
  - neighboring slow suites re-run with the fix: bug_840 (3 failures),
    bug_828 (4 failures), gen_namespacing_827 (1 failure) — EVERY failure
    reproduced identically on pristine master via `git stash` baseline:
    the #840 adopt fixtures predate the #827 namespacing merge, the #828
    doctor tests call the `--feature` API that the merged #840 doctor
    superseded textually (both PRs documented the supersession), and the
    #827 two-feature-same-id scenario fails on master itself. None are
    caused by or touched by this fix.
  - `dart format --set-exit-if-changed` on the changed files -> zero
    diffs (pre-existing drift in migrate_paths_command.dart was committed
    unformatted by #869; untouched here per minimal-diff discipline)
- at: 2026-09-03 (session)
- note: mutation measurement not run this cycle (no mutation_test
  toolchain in the environment); recorded honestly in verification.md as
  the standing gap, per the #828/#840 precedent.
