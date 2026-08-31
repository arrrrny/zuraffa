# Bug Assessment: `zfa tdd run` 6-column deprecation warning — verbose and wrong migration advice

- **Slug**: tdd-run-6col-deprecation-warning
- **Created**: 2026-08-31
- **Source**: GitHub issue #649 (+ assessment accompanying the fix assignment)
- **Verdict**: valid
- **Severity**: medium

## Symptom

`zfa tdd run` prints a deprecation warning to stderr on EVERY run whenever the
feature's `tdd/test-list.md` contains 6-column rows, regardless of who wrote
them or why:

```
zfa: <feature>/tdd/test-list.md: deprecated 6-column test-list rows detected
(id/behavior/traces/kind/state/target). The canonical format is the 4-column
shape `zfa tdd plan <feature>` writes — re-run it to migrate; the 6-column
dialect is accepted for one release.
```

Two independent defects share this one print site:

1. **Verbose for the innocent.** The 6-column shape is not user error in the
   dominant case: the repo's OWN specs/044–049 hand-wrote it (the spec-kit tdd
   extension's shape, sanctioned for one release by spec 050 FR-007). Anyone
   running `zfa tdd run` on those features — or on a copy of them — gets an
   alarming deprecation note for a list they did not create and cannot act on.
   The loop should proceed transparently for spec-sanctioned shapes.
2. **Wrong migration advice.** The note says to migrate by re-running
   `zfa tdd plan <feature>` — but `zfa tdd plan` writes `spec.md` (and the
   4-column `tdd/test-list.md` for a NEW plan), it does not convert an
   existing hand-written 6-column list. Following the advice either does
   nothing to the list or overwrites the user's hand-written list. The correct
   migration for a genuine legacy 6-column list is a MANUAL format conversion
   of `test-list.md` to the 4-column shape.

## Root Cause

`test_list_reader.dart` (pre-fix `:135-143`) printed the deprecation warning
unconditionally whenever `_parseDataRow` flagged a row as `deprecated: true`.
The parser's own doc comment (`test_list_reader.dart:16-37`, pre-fix) records
that 6-column rows arrive in TWO private dialects:

- **gen's old dialect** — `| id | behavior | traces | kind | state | target |`
  where the kind cell names the LOOP (`acceptance`/`unit`). Genuinely legacy;
  produced by old gen output.
- **the tdd extension's hand-written shape** (specs/044–049; spec 050 FR-007)
  — `| id | behavior | traces | kind | state | test |` where the kind cell
  names the test SHAPE (`example`, `property`, `contract`, `approval`,
  `characterization`) and the last cell is a test reference. Spec-sanctioned
  for one release.

`_parseDataRow` returned the same `deprecated: true` for BOTH dialects, so the
`deprecatedDialectWarned` per-file gate (correctly: at most one warning per
file) gated a warning that (a) fired for spec-sanctioned files and (b) named
an impossible migration path.

Row PARSING is correct for both dialects — no false positives/negatives in
what rows mean. Only the warning BEHAVIOR is wrong.

## Reproduction (pre-fix, this session)

`zfa tdd run` on a feature whose list is the repo's own specs/049-tdd-run
6-column extension-shape list (42 rows, all DONE with evidence), run to
completion: exit 0, `result=complete pending=0 red=0 green=0 done=42`, and
stderr contains exactly the wrong-advice warning above. The run's success
path writes nothing else to stderr — the note is the sole stderr content.

## Remediation

Split the warning by dialect; do not touch row parsing:

1. **Spec-sanctioned 6-column files** (the tdd extension shape, specs/044–049
   dialect): suppress the warning ENTIRELY. Valid per spec 050; the user did
   nothing wrong; the loop proceeds transparently (zero stderr).
2. **Genuine legacy 6-column files** (gen's old dialect): keep the one-time
   warning (the `deprecatedDialectWarned` per-file gate is preserved) but
   correct the migration advice to describe a MANUAL format conversion of
   `test-list.md` to the canonical 4-column shape — the advice must NOT name
   `zfa tdd plan` as the test-list migration path.

### Hard constraints

- Fix ONLY the warning behavior in `test_list_reader.dart`; do not change row
  parsing; distinguishing dialects must not introduce false positives or
  negatives in parsing (the parser already handles both shapes correctly).
- Tests asserting on the old message string are updated, not left broken.
- Track the 6-column grace-period cutoff version explicitly (the warning and
  doc comment keep the "accepted for one release" statement; the grace period
  is spec 050's — one release from spec 050's introduction, i.e. through the
  050 remediation release — after which the extension shape itself graduates
  or the rows turn malformed per a future spec).
- One PR for the bug.
