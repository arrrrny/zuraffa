# Cycle Log: 1430-refactor-refresh-evidence

Deterministic fixtures: the CLI/driver rows drive the real make and refactor
command classes in-process over a hermetic temp feature (a subject file under
`lib/tdd/<feature>/`, a certified green cycle-log entry stamped with the
subject's sha256, injectable pass runner — mirroring the existing refactor
suites); no whole-suite runs.

## Baseline

- Behaviors derived: 3 acceptance (A-1430-1..3) + 6 unit (U-1430-1..6).
- Suite entry points: `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart`
  (new) + the existing make/refactor/cycle-log suites for the regression pins.
- RED evidence lands here per cycle as behaviors are driven.

## Cycle 1 — all nine behaviors (the bug)

**RED (pre-fix tree, four behaviors failing for the right reasons):**

```console
$ dart test --preset=all test/plugins/tdd/bug_1430_refresh_evidence_test.dart
00:00 +0 -1 ... A-1430-1 [E]   (make output: the #1036 refusal —
   certified green evidence subject-hash: b64cab8e…,
   current subject-hash: 20a0351a…,
   outcome=subject-drift — the issue's exact dead end)
00:24 +0 -2 ... A-1430-2 [E]   (last hashed evidence = stale green hash ≠ disk)
00:36 +0 -3 ... U-1430-1 [E]   (no `refresh` cycle entry, no forced full re-proof)
02:03 +8 -4 ... U-1430-5 [E]   (no per-behavior refresh entries, scoped re-proof ran)
02:03 +8 -4: Some tests failed.
```

GREEN pre-fix (the pins, behaving exactly as today): A-1430-3 (out-of-band
refusal byte-identical), U-1430-6a/6b/6c/6d (freshness vacuously holds, the
#1162 fail-open and born-green refusal stand), U-1430-2 (misfire reconciles
nothing), U-1430-3 (clean pass byte-equality), U-1430-4 (pending subject →
no refresh). These must stay green through the fix.

**GREEN (post-fix tree, all twelve tests):**

```console
$ dart test --preset=all test/plugins/tdd/bug_1430_refresh_evidence_test.dart
02:17 +12: All tests passed!
```

Implementation that turned the four reds green (smallest change):

- `cycle_entry.dart`: `CycleEntryKind.refresh` + label (renders the
  standard field lines with `- subject-hash:`; never the green
  `generation:`/`suite:` blocks, never the refactor `actions:` block —
  the #1329 precedent: an entry make never certified is never `green`).
- `services/subject_evidence_refresh.dart` (new): `candidates()` maps the
  pass's changed `lib/` paths to registered subjects with certified green
  evidence whose hash ≠ disk; `reconcile()` appends one `refresh` entry
  per candidate carrying the post-rewrite hash and the re-proof command.
- `refactor_command.dart`: candidates computed BEFORE the re-proof and the
  reconciliation runs only on the green success path after the refactor
  evidence append — every failure path returns before it, so a
  refused/misfired/regressed pass never reconciles. The FR-002 honesty
  gate rides the existing scope decision: the scoped covering-test mapping
  sends every changed registered subject to its OWN paired test (each
  candidate's test exercised by construction); every other green path is
  the full suite. An interim forced-full variant was simplified away —
  the covering-test mapping already witnesses each touched subject.
- `make_command.dart` `_subjectDriftRefusal`: the refresh consult —
  accept when the behavior's LAST `refresh` entry matches the CURRENT
  subject hash AND is ISO-8601-newer than the certified basis (fail
  closed on unparseable timestamps); prints the provenance note.

Observed resume (A-1430-1): make prints `subject drift accepted
(issue #1430) … the certified evidence re-binds to it.` and completes
`outcome=skipped` — no `--re-certify`, the loop resumes.


