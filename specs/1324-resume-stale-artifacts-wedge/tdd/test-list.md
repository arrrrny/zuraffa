# TDD Test List — Spec 1324 resume stale-artifacts wedge

One behavior per line, traced to the acceptance criteria (SC-n) in
spec.md. Every behavior is written as a failing test FIRST (RED), then
made to pass (GREEN). Red for this feature is an assertion red: the
wedge survives today (resume re-drives gen over green-but-not-done
behaviors and dead-ends at make `subject-drift`; doctor calls the wedge
healthy). The driver-level suite runs the REAL `RunDriverCore` over the
scripted fake zfa binary (`TddFixture.writeFakeZfa`), mirroring the
issue's repro: a corrupt `artifacts.json` (the kill-mid-write shape),
green-but-not-done A1, fresh pending U6.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Resume skips the green-but-not-done re-drive: with A1 green-but-not-done (red+green evidence, certified test on disk, run-state `green`, registry corrupt) and U6 fresh-pending, `zfa tdd run` completes the feature (`result=complete`), drives A1 at phase 2 only (refactor; make NOT re-driven), and the step log contains NO `gen A1` while U6 gets its full cycle | SC-1 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B2 | The stale-artifacts stop: a make `subject-drift` on a behavior carrying green evidence stops `result=stale-artifacts` at `<id>:make` (exit 1), names the contradiction, prescribes `--> fix: zfa tdd reset <feature>` with the why, drops the generic "fix the failing step" hint, and records the failed step's diagnostics in the cycle log | SC-2 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B3 | The same-drive contradiction: verify-red `unexpected-green` (the skip arm) followed by make `subject-drift` in one behavior drive names `stale-artifacts` too | SC-2 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B4 | Doctor detects the stale-artifacts contradiction: green evidence certified at T1 with a registry record `created_at` T2 > T1 (files present, claims backed) → drift names the behavior id + both timestamps, `verdict=stale-artifacts`, `prescription=reset`, `--> fix: zfa tdd reset <feature>`, exit 1 — never healthy | SC-3 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B5 | Doctor guards: (a) `created_at` BEFORE the certification stays healthy; (b) a legacy green entry without a parseable `- at:` fails open (healthy); (c) evidence-without-artifact keeps its priority — a missing certified test file prescribes resume, not reset | SC-3, SC-4 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B6 | Backward compatibility: a truly red (never green) fresh-pending behavior still resumes from gen — the step log contains `gen U6` and the run completes | SC-4 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |
| B7 | A feature with no green evidence anywhere is unaffected: U6-only run completes end-to-end and the summary line keeps its shape | SC-4 | test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart |

## Red protocol

Run per file, never the full suite (cloud-agent disk ceiling):

```
rm -rf .dart_tool/test/ ; rm -f $TMPDIR/dart_test.kernel.*
dart test --preset=all test/plugins/tdd/bug_1324_resume_stale_artifacts_wedge_test.dart
rm -rf .dart_tool/test/ ; rm -f $TMPDIR/dart_test.kernel.*
```

RED expectation: B1/B2/B3/B4 red (the wedge and the healthy-verdict
survive pre-fix); B5(a/b/c), B6, B7 green (guards over pre-fix
behavior).
