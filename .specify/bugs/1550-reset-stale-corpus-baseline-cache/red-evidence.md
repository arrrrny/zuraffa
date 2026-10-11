# RED Evidence — #1550 reset leaves corpus-wide baseline cache stale

- **Date**: 2026-09-13
- **Suite**: `dart test --preset=all test/plugins/tdd/bug_1550_reset_stale_corpus_baseline_test.dart`
- **Result**: `00:03 +1 -3` — 3 failing (B1, B2, B3), 1 passing (B1 idempotent guard)

## B1 — reset invalidates the baseline caches — FAIL

```
Expected: isFalse (corpus-wide cache exists after reset)
  Actual: <true>
reason: the corpus-wide baseline cache is a third store with the same
        restart contract — reset must invalidate it
```

## B2 — the run after reset re-captures the baseline live — FAIL

The post-reset run reuses the stale corpus-wide snapshot — the exact
failure signature from the issue:

```
zfa tdd run: feature 1550-stale-corpus-baseline — 1 behavior(s)
   suite baseline: corpus-wide reuse (fingerprint match; spec 069 T004) —
   0 pre-existing failure(s) captured 2026-09-13T06:42:08.166249Z; the
   suite is not re-run for this feature
[run] B-001 gen -> ok
...
```

Assertion `isNot(contains('corpus-wide reuse'))` failed: the stale
pre-reset snapshot survived `zfa tdd reset` and was re-affirmed by the
next run.

## B3 — compose refuses a stale green-unit premise — FAIL

Compose reproduced the issue's `runner-error` verbatim (pre-fix):

```
zfa tdd compose: green unit subject "U-001" has no registry record with a
subject_path in .../specs/1550-stale-corpus-baseline/tdd/artifacts.json.
Run `zfa tdd gen U-001` to restore its artifacts.
compose: behavior=A-001 outcome=runner-error feature=1550-stale-corpus-baseline
```

Assertion `contains('outcome=stale-evidence')` failed: the green-unit
premise contradiction (green cycle-log evidence, registry record absent)
was classified `runner-error` instead of an actionable `stale-evidence`
refusal.

## Conclusion

The reproduction stands: reset's restart contract misses the corpus-wide
baseline cache, and compose mislabels the stale green premise as a
runner error. GREEN phase: (a) reset invalidates the corpus-wide +
feature-local baseline caches; (b) discovery returns `stale-evidence`
for a green unit without a registry record and compose maps it to the
`stale-evidence` outcome.
