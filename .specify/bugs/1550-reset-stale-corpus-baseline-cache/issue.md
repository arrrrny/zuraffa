# Issue — #1550: `tdd reset` leaves the corpus-wide baseline cache stale

- **Slug**: 1550-reset-stale-corpus-baseline-cache
- **Source**: https://github.com/arrrrny/zuraffa/issues/1550
- **Fetched**: 2026-09-13
- **Family**: #1505 (corpus-wide baseline cache never invalidates)
- **Related**: #1551 (acceptance compose deadlock — companion issue)

## Verbatim (condensed)

Fresh restart on updated master (4d1dafc7). `zfa tdd reset 001-todo-app`
reported a clean slate (`dropped=51 deleted=102`, green evidence
tombstoned). The very next `tdd run` then hard-stopped at the first
behavior:

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> generation-error
   zfa tdd make: generation step failed at index 0 (compose subject of behavior A1 …):
     command: `… zfa.dart tdd compose A1 --feature 001-todo-app`
     exit: 1
     output: zfa tdd compose: green unit subject "U1" has no registry record with a
       subject_path in specs/001-todo-app/tdd/artifacts.json. Run `zfa tdd gen U1` to restore its artifacts.
   compose: behavior=A1 outcome=runner-error
make: behavior=A1 outcome=generation-error
```

Note `U1` was NOT green — the run had only just generated A1. The
"green" claim came from a **stale cache that `tdd reset` does not
invalidate**:

- `specs/001-todo-app/tdd/run-baseline.json` — rewritten but still
  reporting a baseline captured **2026-09-11T13:24** (pre-reset), and
- **`.zfa/corpus/run-baseline.json`** — the corpus-wide baseline cache
  (spec 069 T004), stamped 2026-09-11, untouched by reset. The run's own
  log shows it being reused: `suite baseline: corpus-wide reuse
  (fingerprint match; spec 069 T004) — 1 pre-existing failure(s)
  captured 2026-09-11T13:24:43Z`.

So the driver resumes with a snapshot of the pre-reset tree, believes U1
(and 40 other dropped behaviors) are green, and composes A1 against
artifacts the reset deleted. The prescribed remedy in the error
(`run zfa tdd gen U1`) is a dead end: there is no way to make A1's make
succeed without either regenerating everything the reset just dropped or
hand-deleting caches the reset owns.

## What's wrong

`tdd reset`'s own doc says it cleans "the two mutable stores a restart
needs clean" (registry + run-state). The corpus-wide baseline cache is a
third store with the same restart contract, and it is left behind — its
fingerprint also matches the pre-reset tree, so nothing re-captures it.
Second-order effect: reset's tombstone invalidates green evidence in the
journal, but the compose planner consults the cache and re-affirms the
invalidated greens.

## Suggested fix (from the issue)

1. **`tdd reset` must invalidate the corpus baseline cache**
   (`.zfa/corpus/run-baseline.json` — or the corpus entry for this
   feature/project) alongside registry + run-state.
2. **Compose must verify its green-unit premise against the registry**
   before composing: a unit advertised green whose registry record is
   absent is itself a refusal-worthy inconsistency — report it as
   `stale-evidence` and re-derive, rather than emitting a `runner-error`
   the operator cannot act on.
3. The corpus cache's fingerprint (spec 069 T004) should include the
   registry/journal generation, so a reset (or any tombstone) forces a
   miss.
