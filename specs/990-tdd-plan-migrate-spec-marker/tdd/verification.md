feature: specs/990-tdd-plan-migrate-spec-marker (issue #990, branch spec/990-tdd-plan-migrate-spec-marker)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree @ 77e69f24 (+ this feature)
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
mutation_score: 5/5 killed # scope: spec_migrator.dart (insert-at-bottom, fence-walk removal, idempotency inversion) + plan_command.dart (persist-skip, fix-line pointer removal) — deliberate manual mutants, each applied to the working tree, each killed by a named test in test/plugins/tdd/issue_990_migrate_spec_test.dart, then reverted (restoration verified by byte-diff)
mutants_survived: 0
equivalent_mutants: 1 # lines.join('\n') as the no-op content — join(split(x)) is identity, semantically equal to specMd; replaced by the detectable idempotency-inversion mutant 3b
suite: "issue_990_migrate_spec_test.dart 8/8 (M0-M7); bug_919_template_structures_test.dart 15/15 (gate contract unchanged); chunked fast suite: 70 chunks, 2902 passed, 0 failed; dart analyze: 345 issues on branch == 345 on master (0 new; all 31 errors pre-existing examples/ Flutter-resolution); dart format: 0 diffs after dart format . (idempotent re-run)"

---

# TDD Verification: issue #990 — `zfa tdd plan --migrate-spec` injects/refreshes the missing template version marker

**Verdict: PASS.** The red→green cycle is real: the RED phase was captured
against the unmodified tree (live CLI repro of the issue's exact symptom,
plus the new test file failing to load because the feature API did not
exist), the GREEN phase was driven by the new suite, and five deliberate
mutants were each killed by a named test. The hard constraints hold: the
`**Template Version**` marker contract (`knownTemplateVersions`, the exit-3
drift gate, the parser's fence-stripping semantics) is unchanged, and the
migration touches nothing in the spec beyond the marker itself.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| A1/U1 — `--migrate-spec` exists, migrates a marker-less spec, and plans in the same run (FR-001/FR-002, AC-1) | PROVEN | RED captured (pre-fix, this session): live CLI `dart run bin/zuraffa.dart tdd plan 005-pr-status-reconciliation --project <fixture>` printed `contract drift — missing '**Template Version**' marker`, **exit 3**; the same run with `--migrate-spec` printed `Could not find an option named "--migrate-spec"`, **exit 64** (no migration path). The new test file additionally failed to LOAD (`Member not found: 'latestTemplateVersion'` ×3) — the API did not exist. GREEN: M3 passes — spec.md's first line is `**Template Version**: `zuraffa-1.0``, the remainder of the file is byte-for-byte the original spec, and the test list is written in the same run (exit 0). Live CLI after the fix: migrate run exit 0 with `migrated spec — inserted`, then a plain re-run exit 0 against the persisted marker. |
| U2 — stale/unknown marker refreshed in place; fenced example never rewritten (FR-003) | PROVEN | M4: a spec pinning `zuraffa-2.0` plans exit 0 after `--migrate-spec`, the file then pins `zuraffa-1.0` and contains no `zuraffa-2.0`. M6: a spec whose only marker mention sits inside a ``` fence gets the real marker inserted at line 1 while the fenced example (including its `zuraffa-2.0` text) survives verbatim. Mutant 2 (fence-walk removed) killed by M6. |
| U3 — migration is idempotent (FR-004) | PROVEN | M5: an already-pinned spec is byte-identical after the run AND prints no `migrated spec` notice. Mutant 3b (idempotency inverted) killed by the strengthened M5; the original mutant 3 (`lines.join('\n')` no-op content) was identified as an equivalent mutant and documented rather than counted. |
| U4 — the drift gate is unchanged without the flag (FR-005) | PROVEN | M0: missing marker without the flag → exit 3, `missing '**Template Version**' marker`, no test list, and spec.md read back with NO `Template Version` text (the gate never mutates the spec). M1: unknown marker without the flag → exit 3. Both mirror the pre-existing bug_919 A4/A5 assertions, which still pass 15/15. |
| U5 — the drift fix line names the migration escape hatch (FR-005 UX) | PROVEN | M2 asserts the exit-3 output contains `--migrate-spec`. Mutant 5 (pointer removed from the fix line) killed by M2. |
| U6 — migration actually persists to spec.md | PROVEN | M3/M4/M6 read spec.md back from disk after the run. Mutant 4 (`writeAsString` skipped, in-run plan still green) killed by 4 test failures. |

## Red-phase evidence (verbatim, pre-fix tree @ 77e69f24)

```text
$ zfa tdd plan 005-pr-status-reconciliation --project /tmp/repro990
zfa tdd plan: contract drift — missing `**Template Version**` marker (spec: ...). No test list was written.
  --> fix: author the spec from the zuraffa spec template (zuraffa speckit extension) so it pins a known template version; re-run `zfa tdd plan`.
EXIT: 3

$ zfa tdd plan 005-pr-status-reconciliation --project /tmp/repro990 --migrate-spec
❌ Could not find an option named "--migrate-spec".
EXIT: 64
```

```text
test/plugins/tdd/issue_990_migrate_spec_test.dart: loading [E]
Error: Member not found: 'latestTemplateVersion'. (×3)
00:00 +0 -1: Some tests failed.
```

## Mutation results (deliberate manual mutants, real apply→test→revert cycles)

| # | Mutant (file) | Change | Killed by | Result |
| --- | --- | --- | --- | --- |
| 1 | spec_migrator.dart | marker inserted at the BOTTOM of the file | M3, M6, M7 (3 failures) | KILLED |
| 2 | spec_migrator.dart | fence tracking removed — fenced example treated as the pin | M6 (1 failure) | KILLED |
| 3 | spec_migrator.dart | no-op content `specMd` → `lines.join('\n')` | — | EQUIVALENT (join∘split = identity) |
| 3b | spec_migrator.dart | `if (known…)` → `if (false && known…)` — pinned spec re-migrated with notice | strengthened M5 (1 failure) | KILLED |
| 4 | plan_command.dart | migrated spec never persisted (`writeAsString` skipped) | M3/M4/M6 (4 failures) | KILLED |
| 5 | plan_command.dart | drift fix line loses the `--migrate-spec` pointer | M2 (1 failure) | KILLED |

Score: 5/5 killed, 0 survived, 1 equivalent documented. Restoration after
each cycle verified by byte-diff against the pre-mutation copies, and the
final tree re-passes `dart format` (0 changed) with 8/8 suite green.

## Test-smell rubric (self-check)

- **Test-after / no-test**: none — the suite existed in RED form (failing
  load) before the implementation files were created.
- **Assertion shopping**: assertions pin exact contracts (first-line
  equality, byte-for-byte remainder, exit codes, absence-of-notice), not
  loose `contains` on incidental output.
- **Tautology**: none — M0/M1 re-prove the OLD gate independently of the
  new code path, and the mutants each changed observable behavior that a
  specific assertion caught.
- **Shared mutable fixtures**: every M-test builds its own temp project
  (`Directory.systemTemp.createTempSync`) and deletes it in tearDown.
- **Over-mocking**: none — tests drive the real `CliRunner` against real
  files on disk; no fakes on the path under test.

## Acceptance-criteria coverage

| Criterion | Covered by |
| --- | --- |
| AC-1 (marker-less spec → inserted at top + report + same-run test list) | M3 + live CLI session evidence |
| FR-001 (flag exists, migrates, then plans) | M3, M4 |
| FR-002 (missing pin injected at top, rest verbatim) | M3, M7 |
| FR-003 (stale pin refreshed in place; fenced example untouched) | M4, M6 |
| FR-004 (idempotent, no churn, no notice) | M5 (strengthened) |
| FR-005 (gate unchanged without the flag; fix line names the hatch) | M0, M1, M2 |

6/6 covered. The spec for this feature (specs/990-tdd-plan-migrate-spec-marker/spec.md)
was itself planned by the real CLI (`zfa tdd plan`, exit 0, 1 acceptance +
5 unit behaviors) — the feature dogfoods its own template gate.

## Constraints audit

- **Template version marker contract unchanged**: `knownTemplateVersions`
  still exactly `{'zuraffa-1.0'}` (now derived from the new
  `latestTemplateVersion` constant — same content, single source of truth);
  the drift gate still exits 3 before parsing; `parseTemplateVersion` is
  untouched. bug_919_template_structures_test.dart passes 15/15 unchanged.
- **Spec semantics beyond the marker untouched**: the migrator rewrites
  exactly one line (refresh) or prepends exactly `**Template Version**:
  `zuraffa-1.0`\n\n` (insert); M3/M7 assert the remainder byte-for-byte.
- **One PR**: all work lands as a single PR closing #990.

## Suite health (full fast suite, this session)

- `tools/run_tests_chunked.sh`: 70/70 chunks, **2902 passed, 0 failed**.
- `dart analyze`: 345 issues on the branch, byte-identical count to master
  (all 31 `error -` lines are the pre-existing `examples/todo_tdd/`
  Flutter-SDK-resolution failures documented in bug #942's verification).
- `dart format .`: idempotent (0 changed on re-run); `git diff --stat`
  after formatting shows only the two intentional source changes.
