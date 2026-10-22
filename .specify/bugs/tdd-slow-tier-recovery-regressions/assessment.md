# Bug Assessment: tdd gen --adopt / reset — the slow tier is red (10 failures)

- **Slug**: tdd-slow-tier-recovery-regressions
- **Created**: 2026-10-21
- **Source**: https://github.com/arrrrny/zuraffa/issues/1979
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`dart test --preset=all` is red at `master`'s tip: **10 tests fail** across three
slow-tier suites. The repo's own `dart_test.yaml` states that `--preset=all` is the
"full-local baseline" and that "a fresh `dart test --preset=all` completes green" —
it does not. The failures are all in the `zfa tdd gen` / `zfa tdd reset` recovery
commands, not in `zfa tdd doctor` or `zfa tdd compose`. Reported while applying
review fixes on PR #1976; the failures are pre-existing and are not caused by that
PR. CI does not catch it: `ci.yaml` runs `dart test test --exclude-tags "flutter ||
e2e"` and the default preset excludes the `slow` tag, so all 10 failures live in the
tier CI does not gate.

The full issue body and the per-test failure table are in the source issue; the
reproduction command and the failure line are quoted verbatim in the Reproduction
section below.

## Symptom

Ten slow-tier tests fail across `bug_840_recovery_commands_test.dart`,
`bug_874_doctor_cross_feature_adoption_test.dart` and
`bug_1397_path_form_mismatch_test.dart`. Three symptom families are visible:

- **A** — `gen --adopt` does not take the adopt path: the flat generated-shape pair
  is left unowned and a *fresh* namespaced pair is created instead (the registry
  records `created`, not `adopted`).
- **B** — `gen` refuses by escaping as a `Bad state:` exception instead of emitting
  the machine-readable JSON verdict, so there is no verdict line at all.
- **C** — `reset` (and the `gen` ownership gate) print a plain-text `key=value`
  summary as their final stdout line instead of the JSON verdict.

## Reproduction

```
dart test --preset=all -j 2 \
  test/plugins/tdd/bug_840_recovery_commands_test.dart \
  test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart \
  test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart \
  test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart \
  test/plugins/tdd/commands/bug_1573_doctor_migrate_prescription_test.dart
```

Observed at `3eed803d` (and at `14b86989`, `master`'s tip):

```
+39 ~1 -10: Some tests failed.
```

The ten failing test names are the issue's table: `bug_840` #1–#5, `bug_874` #6–#9,
`bug_1397` #10. `bug_1495` and `bug_1573` pass in full — the defect is confined to
the `gen` / `reset` paths.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/gen_command.dart` — `_printVerdict`,
  `_printBatchVerdict`, `_generate` (the adopt path, the #1805 criterion guard).
- `lib/src/plugins/tdd/commands/reset_command.dart` — `_printVerdict`.
- `lib/src/plugins/tdd/commands/doctor_command.dart` — `_scanGeneratedLayout`
  (the flat-layout scanner whose `--adopt` prescription `gen` did not honour) and
  `_printVerdict` (the model shape the other two commands had drifted away from).
- `lib/src/plugins/tdd/services/profile_preflight.dart` — the #1528 entry
  preflight that fail-closes a project with no TDD baseline.
- `.specify/bugs/tdd-recovery-commands/tdd/verification.md` — the authoritative
  bug-#840 contract: *every command's final stdout line is a parseable JSON
  object*.

## Root Cause Hypothesis

High confidence. **Four independent regressions**, not one — the slow tier is
excluded from CI, so nothing caught them:

1. **The JSON verdict contract was lost for `gen` and `reset`.** Bug #840's own
   verification record mandates that every recovery command's final stdout line is
   a parseable JSON object. `zfa tdd doctor` still emits it; `gen`/`reset` had
   drifted to a plain-text `key=value` summary behind the `--json` gate, so the
   recovery tooling could no longer parse their verdict. (6 failures.)
2. **`gen --adopt` was blind to the legacy flat layout.** #827 namespaced artifacts
   to `test/tdd/<feature>/…`, but `doctor._scanGeneratedLayout` still scans the
   FLAT layout (`test/tdd/*.dart` + `lib/tdd/*.dart`) and prescribes `--adopt` for
   flat orphans. The two commands never shared one scanner, so the doctor's answer
   and `gen`'s behaviour drifted apart — the prescription was a dead end.
   (3 failures.)
3. **The #1805 criterion guard threw instead of refusing.** `throw StateError(...)`
   escaped the exit protocol, so a refusal produced no verdict line at all. The
   house pattern (spec 048) is exit code + return. (1 failure.)
4. **The #1528 entry preflight aborted the flow.** `zfa tdd gen` auto-runs
   `zfa tdd init` when `.specify/memory/tdd-profile.md` is missing; the init's
   `pubspec_dev_dependencies_patcher` misfires on a project with no
   `pubspec.yaml` and the preflight fail-closes with `setup-error`. The product
   behavior is correct by design — the *fixture* was incomplete. (1 failure.)

## Proposed Remediation

**Preferred**: restore the contract on both sides.

- `gen` and `reset` print the human-readable `key=value` summary **and then** the
  raw JSON verdict as the FINAL stdout line when `--json` is absent — the shape
  `zfa tdd doctor` already emits. The `--json` envelope path
  (`zuraffa.verdict.v1`) stays untouched, so the machine-line contract of #969 is
  preserved.
- The #1805 criterion-mismatch guard refuses through the house pattern
  (`_printVerdict(verdict: 'refused', …)` + `exitCode = 1` + `return 'refused'`)
  instead of throwing.
- `gen --adopt` falls back to the legacy flat candidates: when the namespaced pair
  is absent, no registry record claims the behavior and a flat candidate exists,
  the pair is adopted IN PLACE — the flat candidate's own directory, so the
  adopted half's relative subject import keeps resolving and the missing half is
  generated beside it (never in a second directory). The recorded artifact paths
  are composed *after* the adoption, so the registry carries the paths the pair
  really occupies.
- The `bug_1397` fixture project seeds a minimal `pubspec.yaml` so the #1528
  preflight can complete. The product's fail-closed behavior is unchanged and no
  test assertion is weakened — this is a fixture-completeness repair.

**Alternatives**:
- Re-point `doctor._scanGeneratedLayout` at the namespaced layout instead. That
  would fix the symptom but silently drop the doctor's ability to diagnose
  pre-#827 artifacts, and it changes a command the issue did not name.
- Weaken the suites to accept the text summary. That would delete the contract
  bug #840 established — not acceptable.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart`
- `lib/src/plugins/tdd/commands/reset_command.dart`
- `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart`

**Tests to add or update**:
- No new test file: the ten failing slow-tier tests ARE the regression tests, and
  they lock the fix in (the bug-#840 contract is asserted by their `verdict()`
  helper, which `jsonDecode`s the final stdout line).
- The `bug_1397` fixture gains a `pubspec.yaml` so the #1528 preflight completes.

## Risks & Considerations

- The `--json` envelope path must not change: `bug_969_json_verdict_envelope_test.dart`
  and `gen_command_platform_test.dart` assert `schema: zuraffa.verdict.v1` and the
  `kind`/`golden` fields inside it.
- A non-`--json` invocation now ends with a machine line. Anything that reads the
  final stdout line as *text* would now see JSON — the recovery tooling expects
  exactly that, but the shape must stay a single parseable object.
- Adopting the flat layout must keep the adopted half's relative subject import
  resolving; re-pointing the pair into a different directory would break it.
- The three `bug_1272_gen_project_scoped_test_list_test.dart` REGRESSION GUARD
  failures are **pre-existing on clean `master`** (verified in a separate worktree
  at `14b86989`: same three failures, same `setup-error` cause) and are a
  separate defect — out of scope here.

## Open Questions

None. Every question the report raised is answered by the reproduction above: the
10 failures are reproducible, confined to `gen`/`reset`, and caused by the four
regressions listed in the Root Cause Hypothesis.
