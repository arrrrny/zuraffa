# Quickstart: 1430-refactor-refresh-evidence

Validation guide for the refactor-pass evidence refresh (issue #1430).

## Prerequisites

- Dart ^3.11.0 (3.13 stable validated). Pure-Dart root package.
- From the repo root: `dart pub get` once.

## Automated validation (the gate)

```bash
# feature-scoped suite (the profile's feature scope)
dart test test/plugins/tdd/

# static analysis on the touched files
dart analyze lib/src/plugins/tdd/ test/plugins/tdd/
```

The feature's behaviors live in `specs/1430-refactor-refresh-evidence/tdd/test-list.md`
(each traces to a spec FR/scenario). The cycle log records red→green
evidence per behavior.

## Manual end-to-end proof (the issue's repro)

The defect repro, now expected to resume clean:

1. Create a scratch project with a planned feature whose test list holds an
   acceptance behavior A1 and a vacuous-guard (hand-delta) behavior A2.
2. `zfa tdd run <feature>` — observe A1 certify green (cycle log records
   `subject-hash`), the refactor cycle run (`dart format lib/`,
   `dart fix --apply lib/`), and the run stop at `A2:hand`.
3. Confirm the refactor appended `## Cycle: A1 (refresh)` entries carrying
   the post-rewrite `subject-hash` (and printed the full-re-proof note when
   A1's subject was rewritten).
4. Re-run `zfa tdd run <feature>` — expected: A1's make skip transition
   prints the `subject drift accepted (issue #1430)` note and the run
   advances to A2. NOT expected: `subject-drift (stale-artifacts)` /
   "cannot resume through the loop".
5. Negative control: hand-edit A1's certified subject out-of-band, re-run —
   expected: the existing `subject-drift` refusal with hash mismatch,
   unchanged.

## Sanity invariants after any run

- `tdd/cycle-log.md` gained only appended sections (no edited history;
  `- prev-hash:` chain intact).
- No `refresh` entry exists for a behavior without certified green
  evidence, or for a re-proof that failed.
- `zfa tdd verify-red <id> --re-certify` (the #1162 remedy) still works for
  genuine drift — it is untouched by this feature.
